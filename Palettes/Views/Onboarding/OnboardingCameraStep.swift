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
    /// `makePalette` is set without Apple Intelligence: the frozen photo then
    /// becomes the palette as is, with no color to pick.
    func stepContent(reduceMotion: Bool, chooseColor: @escaping () -> Void,
                     makePalette: (() -> Void)? = nil) -> OnboardingStepContent {
        if model.isPhotoFrozen, let makePalette {
            return OnboardingStepContent(
                key: "picked-photo",
                eyebrow: .init(title: "Got it", systemImage: "camera.aperture"),
                title: "Turn it into a palette",
                subtitle: "We\u{2019}ll pull the colors that stand out right out of this photo.",
                primary: .init(title: "Make my palette", systemImage: "swatchpalette", action: makePalette),
                secondary: .button("Retake") { [self] in retake() }
            )
        }
        if model.isPhotoFrozen {
            return OnboardingStepContent(
                key: "picked",
                eyebrow: .init(title: "Got it", systemImage: "camera.aperture"),
                title: "Pick your color",
                subtitle: "Open the photo and drag to the exact shade you love.",
                primary: .init(title: "Pick Color", systemImage: "eyedropper", action: chooseColor),
                secondary: .button("Retake") { [self] in retake() }
            )
        }
        if showsStill {
            return OnboardingStepContent(
                key: "still",
                eyebrow: .init(title: "Look around", systemImage: "photo"),
                title: "Find a color you love",
                subtitle: pickedImage == nil
                    ? fallbackMessage
                    : (makePalette == nil ? "Use this photo to pick a color." : "Use this photo to make a palette."),
                body: model.cameraAccess == .denied ? AnyView(OpenSettingsLink()) : nil,
                primary: .init(title: "Use this photo", isEnabled: !isScanning) { [self] in scan(reduceMotion: reduceMotion) },
                secondary: photoPicker
            )
        }
        if model.cameraUIState == .needsPermission {
            return OnboardingStepContent(
                key: "permission",
                eyebrow: .init(title: "Your camera", systemImage: "camera.fill"),
                title: "See the world in color",
                subtitle: "Your camera becomes a color finder. Nothing is saved or uploaded.",
                // Not worded like the system alert's buttons (App Review 5.1.1(iv)).
                primary: .init(title: "Continue") { [self] in requestAccess() },
                secondary: photoPicker
            )
        }
        return OnboardingStepContent(
            key: "live",
            eyebrow: .init(title: "Look around", systemImage: "viewfinder"),
            title: "Find a color you love",
            subtitle: camera.isInterrupted
                ? "Camera paused while another app is using it."
                : "Point at anything that catches your eye, then tap Scan.",
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
