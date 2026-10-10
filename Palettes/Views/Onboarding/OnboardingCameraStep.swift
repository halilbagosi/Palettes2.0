//
//  OnboardingCameraStep.swift
//  Palettes
//
//  What the camera step says and offers in each of its states: permission not
//  yet decided, live camera, the photo/sample fallback, and "picked" (the photo
//  frozen in the orb's window after Scan, waiting for a spot to be chosen).
//

import SwiftUI
import PhotosUI

extension OnboardingCameraFlow {
    func stepContent(reduceMotion: Bool, chooseColor: @escaping () -> Void) -> OnboardingStepContent {
        if model.isPhotoFrozen {
            return OnboardingStepContent(
                key: "picked",
                title: "Pick your color",
                subtitle: "Open the photo and drag to the color you love.",
                primary: .init(title: "Pick Color", systemImage: "eyedropper", action: chooseColor),
                secondary: .button("Retake") { [self] in retake() }
            )
        }
        if showsStill {
            return OnboardingStepContent(
                key: "still",
                title: "Find a color",
                subtitle: pickedImage == nil ? fallbackMessage : "Use this photo to pick a color.",
                body: model.cameraAccess == .denied ? AnyView(OpenSettingsLink()) : nil,
                primary: .init(title: "Use this photo", isEnabled: !isScanning) { [self] in scan(reduceMotion: reduceMotion) },
                secondary: photoPicker
            )
        }
        if model.cameraUIState == .needsPermission {
            return OnboardingStepContent(
                key: "permission",
                title: "See the world in color",
                subtitle: "Palettes uses your camera to find colors. Nothing is saved or uploaded.",
                // Not worded like the system alert's buttons (App Review 5.1.1(iv)).
                primary: .init(title: "Continue") { [self] in requestAccess() },
                secondary: photoPicker
            )
        }
        return OnboardingStepContent(
            key: "live",
            title: "Find a color",
            subtitle: camera.isInterrupted
                ? "Camera paused while another app is using it."
                : "Point your camera at something you love.",
            primary: .init(title: "Scan", systemImage: "camera.aperture",
                           isEnabled: !isScanning && !camera.isInterrupted) { [self] in scan(reduceMotion: reduceMotion) },
            secondary: photoPicker
        )
    }

    private var photoPicker: OnboardingStepContent.Secondary {
        let binding = Binding<PhotosPickerItem?>(
            get: { self.photosPickerItem },
            set: { self.photosPickerItem = $0 }
        )
        return .init(view: AnyView(
            PhotosPicker(selection: binding, matching: .images) {
                Text("Choose a photo")
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isScanning)
        ))
    }
}

private struct OpenSettingsLink: View {
    var body: some View {
        OnboardingSecondaryButton(title: "Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}
