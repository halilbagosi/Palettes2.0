//
//  OnboardingCameraFlow.swift
//  Palettes
//
//  The logic of the camera step, kept out of the views: permission, the live
//  session, a picked photo, and Scan (flash, freeze, pulse). It owns the
//  `OrbCameraController`, whose changes it forwards so views update.
//

import SwiftUI
import PhotosUI
import AVFoundation
import Combine

@MainActor
final class OnboardingCameraFlow: ObservableObject {
    let model: OnboardingModel
    let camera = OrbCameraController()

    @Published var pickedImage: UIImage?
    @Published var photosPickerItem: PhotosPickerItem?
    @Published private(set) var isScanning = false
    @Published private(set) var pickerError: String?
    /// White shutter flash inside the window.
    @Published private(set) var flash: Double = 0
    /// Scale of the window for the "tap me" pulse after Scan.
    @Published private(set) var windowScale: CGFloat = 1
    @Published private(set) var scanCount = 0

    private var isSceneActive = true
    private var scanTask: Task<Void, Never>?
    private var pickerTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()

    init(model: OnboardingModel) {
        self.model = model
        camera.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
        camera.$didFailToConfigure
            .filter { $0 }
            .sink { [weak self] _ in self?.model.cameraAccess = .unavailable }
            .store(in: &bag)
    }

    // MARK: Derived

    /// The window shows a still (sample, or the chosen photo) instead of the camera.
    var showsStill: Bool { model.cameraUIState == .photoFallback || pickedImage != nil }
    var stillImage: UIImage { pickedImage ?? OnboardingSampleImage.shared }

    /// What the orb's window shows for the camera step.
    var windowContent: OrbWindowContent {
        if let frozen = model.capturedImage { return .photo(frozen) }
        if showsStill { return .photo(stillImage) }
        if model.cameraUIState == .live { return .camera(camera, camera.device) }
        return .empty
    }

    var fallbackMessage: String {
        switch model.cameraAccess {
        case .denied, .restricted: "Camera access is off. Use the sample, or pick a photo."
        default:
            camera.didFailToConfigure
                ? "Camera isn't available right now. Use the sample, or pick a photo."
                : "No camera here. Use the sample, or pick a photo."
        }
    }

    // MARK: Permission

    func refreshAccess() {
        // Start from the status alone so granted users never see the pre-prompt flash.
        model.cameraAccess = .quick()
        Task { model.cameraAccess = await .current() }
    }

    func requestAccess() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            model.cameraAccess = .quick()
            model.cameraAccess = await .current()
        }
    }

    // MARK: Session

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        updateSession()
    }

    /// The session only runs while the camera step is visible, the app is
    /// active, access is granted, and nothing is frozen or picked.
    func updateSession() {
        let wanted = model.step == .camera
            && isSceneActive
            && model.cameraUIState == .live
            && model.capturedImage == nil
            && pickedImage == nil
        if wanted { camera.start() } else { camera.stop() }
    }

    func stop() {
        camera.stop()
        scanTask?.cancel()
        pickerTask?.cancel()
    }

    // MARK: Photos

    func loadPickedPhoto() {
        guard let item = photosPickerItem else { return }
        pickerTask?.cancel()
        pickerError = nil
        pickerTask = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let image: UIImage? = if let data {
                await Task.detached { OnboardingImageLoader.downscaled(from: data) }.value
            } else {
                nil
            }
            guard !Task.isCancelled else { return }
            if let image {
                withAnimation(.easeInOut(duration: 0.4)) {
                    model.capturedImage = nil
                    pickedImage = image
                }
                updateSession()
            } else {
                pickerError = "Couldn't load that photo. Try another."
            }
            // Lets the same photo be picked again.
            photosPickerItem = nil
        }
    }

    // MARK: Scan

    /// Flash, haptic and freeze, then stay on the step in its "picked" state.
    func scan(reduceMotion: Bool) {
        guard !isScanning, !model.isPhotoFrozen else { return }
        isScanning = true
        scanTask = Task {
            let image: UIImage?
            if showsStill {
                image = stillImage
            } else if let data = await camera.capturePhoto() {
                image = await Task.detached { OnboardingImageLoader.downscaled(from: data) }.value
            } else {
                image = nil
            }
            guard !Task.isCancelled, let image else {
                isScanning = false
                return
            }
            // Same frame: haptic (via scanCount), flash up, photo frozen.
            scanCount += 1
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.3)) { model.capturedImage = image }
            } else {
                withAnimation(.easeOut(duration: 0.06)) { flash = 0.9 }
                model.capturedImage = image
                withAnimation(.easeIn(duration: 0.12).delay(0.06)) { flash = 0 }
            }
            updateSession()
            isScanning = false
            if !reduceMotion { await pulseWindow() }
        }
    }

    /// 1 -> 1.04 -> 1, twice, then it stops.
    private func pulseWindow() async {
        try? await Task.sleep(for: .milliseconds(350))
        for _ in 0..<2 {
            guard !Task.isCancelled, model.isPhotoFrozen else { break }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { windowScale = 1.04 }
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { windowScale = 1 }
            try? await Task.sleep(for: .milliseconds(420))
        }
        windowScale = 1
    }

    /// Back to the live camera (or the sample/picked photo) from the picked state.
    func retake() {
        scanTask?.cancel()
        isScanning = false
        windowScale = 1
        withAnimation(.easeInOut(duration: 0.4)) { model.capturedImage = nil }
        updateSession()
    }
}
