//
//  OnboardingModel.swift
//  Palettes
//
//  Pure state for the first-launch onboarding: the step machine, camera
//  permission fallback, and the color the user scans. No UI, persistence, or
//  framework dependencies, so it is fully unit-testable. The presenter owns
//  the completion flag and navigation; the model only reports how it ended.
//

import Foundation
import Combine
import UIKit

/// Steps shown inside the full-screen cover. The detail-screen coach mark and
/// the extras cards happen after the cover dismisses, so they are not steps
/// here (TODO: track them with their own `@AppStorage` keys in `OnboardingKeys`).
enum OnboardingStep: Int, CaseIterable {
    case pull, orb, camera, adjust, generate
}

enum OnboardingKeys {
    /// Per-device flag read by `PaletteTabView` via `@AppStorage`.
    static let didComplete = "didCompleteOnboarding"
    /// Set once the detail-screen coach mark has been shown; it never returns.
    static let didShowCoachMark = "didShowOnboardingCoachMark"
}

enum OnboardingFinishReason: Equatable {
    case skipped
    /// The user generated a palette; the presenter can navigate to it.
    case completed(paletteID: UUID)
}

/// Camera availability as onboarding sees it, decoupled from AVFoundation.
enum OnboardingCameraAccess {
    case notDetermined, authorized, denied, restricted
    /// No capture device (e.g. the simulator).
    case unavailable
}

/// What the camera step shows, derived from `OnboardingCameraAccess`.
enum OnboardingCameraUIState: Equatable {
    /// Not asked yet: show the pre-prompt line and an Allow button.
    case needsPermission
    case live
    /// Denied, restricted, or no camera: photo picker and sample image.
    case photoFallback
}

/// Pull-down gesture math for step 0.
enum OnboardingPull {
    /// The rubber-banded stretch approaches this but never reaches it.
    static let maxStretch: Double = 220
    /// Raw finger travel (points) at which the orb detaches.
    static let commitThreshold: Double = 130

    /// Maps raw finger travel to a resisted on-screen stretch.
    static func rubberBand(_ translation: Double) -> Double {
        guard translation > 0 else { return 0 }
        return maxStretch * (1 - 1 / (translation / maxStretch * 0.55 + 1))
    }

    /// A fast flick commits even when the finger travel is short: the
    /// predicted end translation counts at half weight.
    static func shouldCommit(translation: Double, predictedEnd: Double = 0) -> Bool {
        max(translation, predictedEnd * 0.5) >= commitThreshold
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var step: OnboardingStep = .pull
    @Published private(set) var isFinished = false
    @Published var cameraAccess: OnboardingCameraAccess = .notDetermined
    /// The frozen scan (or chosen photo) shown inside the orb after Scan.
    @Published var capturedImage: UIImage?
    /// Sampled color, 0...255 per channel; set once the user scans.
    @Published var scannedRGB: (r: Double, g: Double, b: Double)?
    /// Adjustment slider positions in `ColorAdjustment`'s convention (0...1, 0.5 neutral).
    @Published var brightness = 0.5
    @Published var saturation = 0.5

    /// The scanned color after the brightness and saturation sliders.
    /// Temperature stays neutral: onboarding adjusts only those two.
    var adjustedRGB: (r: Double, g: Double, b: Double)? {
        guard let rgb = scannedRGB else { return nil }
        return ColorAdjustment.apply(
            baseR: rgb.r, baseG: rgb.g, baseB: rgb.b,
            temperature: 0.5, saturation: saturation, brightness: brightness
        )
    }

    /// `#RRGGBB` of the adjusted color: the anchor the palette is built from.
    var selectedHex: String? {
        adjustedRGB.map { ColorAdjustment.hexString(r: $0.r, g: $0.g, b: $0.b) }
    }

    private let onFinish: (OnboardingFinishReason) -> Void

    /// `onFinish` fires exactly once and is the presenter's only cue to dismiss.
    init(onFinish: @escaping (OnboardingFinishReason) -> Void = { _ in }) {
        self.onFinish = onFinish
    }

    /// Denied, restricted, or missing cameras route to the photo/sample fallback.
    var usesPhotoFallback: Bool {
        switch cameraAccess {
        case .denied, .restricted, .unavailable: true
        case .notDetermined, .authorized: false
        }
    }

    var cameraUIState: OnboardingCameraUIState {
        switch cameraAccess {
        case .notDetermined: .needsPermission
        case .authorized: .live
        case .denied, .restricted, .unavailable: .photoFallback
        }
    }

    /// Moves to the next step. The last step has no successor: it ends through
    /// `finish(_:)` because completing needs the generated palette's id.
    func advance() {
        guard !isFinished, let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func skip() {
        finish(.skipped)
    }

    func finish(_ reason: OnboardingFinishReason) {
        guard !isFinished else { return }
        isFinished = true
        onFinish(reason)
    }
}
