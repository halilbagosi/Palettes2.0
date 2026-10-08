//
//  OrbCameraPreview.swift
//  Palettes
//
//  Live back-camera preview for the onboarding orb, plus the session
//  engine/controller, the capture coordinator, image downscaling, and the
//  pure permission-to-state mapping.
//

import SwiftUI
import Combine
import AVFoundation
import ImageIO
import UIKit

// MARK: - Permission mapping

nonisolated extension OnboardingCameraAccess {
    /// Maps the system authorization status (and whether a camera exists) to
    /// onboarding's camera state. A missing camera wins over any status.
    init(status: AVAuthorizationStatus, hasDevice: Bool) {
        guard hasDevice else {
            self = .unavailable
            return
        }
        switch status {
        case .authorized: self = .authorized
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .notDetermined: self = .notDetermined
        @unknown default: self = .denied
        }
    }

    /// The device's current camera state. The device lookup can block, so it
    /// runs off the main thread. The simulator has no camera, so it goes
    /// straight to the photo/sample fallback without prompting.
    static func current() async -> OnboardingCameraAccess {
#if targetEnvironment(simulator)
        return .unavailable
#else
        await Task.detached(priority: .userInitiated) {
            let hasDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
            return OnboardingCameraAccess(
                status: AVCaptureDevice.authorizationStatus(for: .video),
                hasDevice: hasDevice
            )
        }.value
#endif
    }
}

// MARK: - Capture coordinator

/// Collects one photo capture's result and resumes its caller exactly once,
/// whichever comes first: the capture finishing, an error, or `cancel()`.
/// Kept free of AVFoundation types so its callbacks can be driven in tests.
nonisolated final class PhotoCaptureCoordinator: @unchecked Sendable {
    // The lock guards `data` and `completion`; callbacks arrive on arbitrary queues.
    private let lock = NSLock()
    private var data: Data?
    private var completion: (@Sendable (Data?) -> Void)?

    init(completion: @escaping @Sendable (Data?) -> Void) {
        self.completion = completion
    }

    /// The processed photo is ready (maps to `didFinishProcessingPhoto`).
    func didProcess(data: Data?, error: Error?) {
        lock.lock()
        if error == nil { self.data = data }
        lock.unlock()
    }

    /// The whole capture is done (maps to `didFinishCaptureFor`); resumes.
    func didFinishCapture(error: Error?) {
        lock.lock()
        let result = error == nil ? data : nil
        lock.unlock()
        finish(result)
    }

    /// Abandons the capture (e.g. the session stopped); resumes with nil.
    func cancel() {
        finish(nil)
    }

    private func finish(_ result: Data?) {
        lock.lock()
        let completion = self.completion
        self.completion = nil
        lock.unlock()
        completion?(result)
    }
}

nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    // Immutable after init.
    private let coordinator: PhotoCaptureCoordinator

    init(coordinator: PhotoCaptureCoordinator) {
        self.coordinator = coordinator
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        coordinator.didProcess(data: photo.fileDataRepresentation(), error: error)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {
        coordinator.didFinishCapture(error: error)
    }
}

// MARK: - Session engine

/// Owns the capture session. Every session call runs on a private serial
/// queue, never the main thread. Deliberately `nonisolated` so the module's
/// MainActor default doesn't pull these calls onto the main actor.
///
/// `@unchecked Sendable` is justified because all mutable state is confined
/// to `queue`, except the capture rotation angle, which has its own lock.
nonisolated final class OrbCameraEngine: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "palettes.onboarding.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var hasReportedFailure = false
    private var inFlight: PhotoCaptureCoordinator?
    private var inFlightDelegate: PhotoDelegate?
    private var onConfigured: (@Sendable (AVCaptureDevice) -> Void)?
    private var onFailure: (@Sendable () -> Void)?

    private let angleLock = NSLock()
    private var captureAngle: CGFloat = 90

    /// Callbacks fire on the engine's queue; hop to the main actor yourself.
    func setCallbacks(onConfigured: @escaping @Sendable (AVCaptureDevice) -> Void,
                      onFailure: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            self.onConfigured = onConfigured
            self.onFailure = onFailure
        }
    }

    /// Fed by the preview's rotation coordinator (main thread); read at capture.
    func setCaptureAngle(_ angle: CGFloat) {
        angleLock.lock()
        captureAngle = angle
        angleLock.unlock()
    }

    func start() {
        queue.async { [self] in
            guard configureIfNeeded() else {
                if !hasReportedFailure {
                    hasReportedFailure = true
                    onFailure?()
                }
                return
            }
            if !session.isRunning { session.startRunning() }
        }
    }

    /// Stops the session and resumes any in-flight capture with nil, so a
    /// caller awaiting `capturePhoto()` can never hang.
    func stop() {
        queue.async { [self] in
            inFlight?.cancel()
            inFlight = nil
            inFlightDelegate = nil
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures a still as encoded image data, or nil if the session isn't
    /// running, capture fails, or the session stops mid-capture.
    func capturePhoto() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let coordinator = PhotoCaptureCoordinator { [weak self] data in
                    self?.queue.async {
                        self?.inFlight = nil
                        self?.inFlightDelegate = nil
                    }
                    continuation.resume(returning: data)
                }
                let delegate = PhotoDelegate(coordinator: coordinator)
                inFlight = coordinator
                inFlightDelegate = delegate

                angleLock.lock()
                let angle = captureAngle
                angleLock.unlock()
                if let connection = photoOutput.connection(with: .video),
                   connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
                photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }

    /// Runs on `queue`.
    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canSetSessionPreset(.photo) else { return false }
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        isConfigured = true
        onConfigured?(device)
        return true
    }
}

// MARK: - Controller

/// Main-actor face of the engine for SwiftUI: publishes the configured
/// device, configuration failure, and interruptions.
final class OrbCameraController: ObservableObject {
    @Published private(set) var device: AVCaptureDevice?
    @Published private(set) var didFailToConfigure = false
    @Published private(set) var isInterrupted = false

    private let engine = OrbCameraEngine()
    private var observers: [NSObjectProtocol] = []

    var session: AVCaptureSession { engine.session }

    init() {
        bindEngine()
        observeInterruptions()
    }

    private func bindEngine() {
        engine.setCallbacks(
            onConfigured: { [weak self] device in
                guard let self else { return }
                Task { @MainActor in self.device = device }
            },
            onFailure: { [weak self] in
                guard let self else { return }
                Task { @MainActor in self.didFailToConfigure = true }
            }
        )
    }

    private func observeInterruptions() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                               object: engine.session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isInterrupted = true }
            },
            center.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
                               object: engine.session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.isInterrupted = false }
            },
        ]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    func start() { engine.start() }
    func stop() { engine.stop() }
    func setCaptureAngle(_ angle: CGFloat) { engine.setCaptureAngle(angle) }

    func capturePhoto() async -> Data? { await engine.capturePhoto() }
}

// MARK: - Preview view

/// Aspect-fill preview of a session, rotated with the device via a rotation
/// coordinator. The orb view masks it to a circle with a faded edge, so it
/// reads as living inside the glass.
struct OrbCameraPreview: UIViewRepresentable {
    let controller: OrbCameraController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = controller.session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let device = controller.device {
            uiView.attach(device: device) { [controller] angle in
                controller.setCaptureAngle(angle)
            }
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        private var rotation: AVCaptureDevice.RotationCoordinator?
        private var observations: [NSKeyValueObservation] = []
        private var previewAngle: CGFloat = 90

        /// Starts tracking device rotation once the camera is known: the
        /// preview connection follows the preview angle, and the capture angle
        /// is forwarded for the photo output.
        func attach(device: AVCaptureDevice, onCaptureAngle: @escaping @Sendable (CGFloat) -> Void) {
            guard rotation == nil else { return }
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            rotation = coordinator
            applyPreviewAngle(coordinator.videoRotationAngleForHorizonLevelPreview)
            onCaptureAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
            observations = [
                coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                    let angle = coordinator.videoRotationAngleForHorizonLevelPreview
                    DispatchQueue.main.async { self?.applyPreviewAngle(angle) }
                },
                coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { coordinator, _ in
                    onCaptureAngle(coordinator.videoRotationAngleForHorizonLevelCapture)
                },
            ]
        }

        private func applyPreviewAngle(_ angle: CGFloat) {
            previewAngle = angle
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The preview connection can appear after the first angle arrives.
            applyPreviewAngle(previewAngle)
        }
    }
}

// MARK: - Images

nonisolated enum OnboardingImageLoader {
    static let maxPixelSize = 1536

    /// Decodes image data into an orientation-applied thumbnail no larger than
    /// `maxPixel` on its long side. Does the work of reading, so call it off
    /// the main thread.
    static func downscaled(from data: Data, maxPixel: Int = maxPixelSize) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

enum OnboardingSampleImage {
    /// Rendered once, on first use. At 1x and 400pt it is a few hundred KB.
    static let shared = make()

    /// A colorful stand-in for the camera (simulator, denied access, no
    /// camera), rendered in code so no binary asset is needed.
    static func make(size: CGSize = CGSize(width: 400, height: 400)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let sky = [UIColor(red: 0.98, green: 0.62, blue: 0.45, alpha: 1).cgColor,
                       UIColor(red: 0.86, green: 0.45, blue: 0.62, alpha: 1).cgColor,
                       UIColor(red: 0.35, green: 0.33, blue: 0.62, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: sky as CFArray, locations: [0, 0.55, 1]) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: 0, y: size.height), options: [])
            }
            UIColor(red: 1, green: 0.88, blue: 0.55, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: size.width * 0.52, y: size.height * 0.2,
                                      width: size.width * 0.3, height: size.width * 0.3))
            UIColor(red: 0.16, green: 0.24, blue: 0.36, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.78, width: size.width, height: size.height * 0.22))
        }
    }
}
