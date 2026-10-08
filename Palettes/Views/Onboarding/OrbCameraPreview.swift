//
//  OrbCameraPreview.swift
//  Palettes
//
//  Live back-camera preview for the onboarding orb, plus the session
//  controller and the pure permission-to-state mapping.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Permission mapping

extension OnboardingCameraAccess {
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

    /// The device's current camera state. The simulator has no camera, so it
    /// goes straight to the photo/sample fallback without prompting.
    static func current() -> OnboardingCameraAccess {
#if targetEnvironment(simulator)
        return .unavailable
#else
        let hasDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        return OnboardingCameraAccess(
            status: AVCaptureDevice.authorizationStatus(for: .video),
            hasDevice: hasDevice
        )
#endif
    }
}

// MARK: - Session controller

/// Owns the capture session. Every session call runs on a private serial
/// queue, never the main thread. Deliberately `nonisolated` so the module's
/// MainActor default doesn't force these calls onto the main actor.
nonisolated final class OrbCameraController: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "palettes.onboarding.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var inFlight: PhotoDelegate?

    func start() {
        queue.async { [self] in
            guard configureIfNeeded(), !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures a still, or nil if the session isn't running or capture fails.
    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let delegate = PhotoDelegate { [weak self] image in
                    self?.queue.async { self?.inFlight = nil }
                    continuation.resume(returning: image)
                }
                inFlight = delegate
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
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        isConfigured = true
        return true
    }
}

nonisolated private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: @Sendable (UIImage?) -> Void

    init(completion: @escaping @Sendable (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }
        completion(image)
    }
}

// MARK: - Preview view

/// Aspect-fill preview of a session. The orb view masks it to a circle with a
/// faded edge, so it reads as living inside the glass.
struct OrbCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Sample image

enum OnboardingSampleImage {
    /// A colorful stand-in for the camera (simulator, denied access, no
    /// camera), rendered in code so no binary asset is needed.
    static func make(size: CGSize = CGSize(width: 600, height: 600)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
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
