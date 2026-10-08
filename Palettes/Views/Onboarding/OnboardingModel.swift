//
//  OnboardingModel.swift
//  Palettes
//
//  Pure state for the first-launch onboarding: the step machine, camera
//  permission fallback, and the color the user scans. No views or persistence
//  (it imports UIKit/Combine only for `UIImage` and `ObservableObject`), so it
//  is fully unit-testable. The presenter owns
//  the completion flag and navigation; the model only reports how it ended.
//

import Foundation
import Combine
import UIKit

/// Steps shown inside the full-screen cover. The detail-screen coach mark and
/// the extras cards happen after the cover dismisses, so they are not steps
/// here; they track themselves with the `OnboardingKeys` flags below.
enum OnboardingStep: Int, CaseIterable {
    case pull, orb, camera, adjust, generate
}

enum OnboardingKeys {
    /// Per-device flag read by `PaletteTabView` via `@AppStorage`.
    static let didComplete = "didCompleteOnboarding"
    /// Set once the detail-screen coach mark has been shown; it never returns.
    static let didShowCoachMark = "didShowOnboardingCoachMark"
    /// Set once the post-onboarding extras sheet has been shown.
    static let didShowExtras = "didShowOnboardingExtras"

    /// Replay from Settings: the whole experience runs again, including the
    /// one-time coach mark and extras sheet.
    static func resetForReplay(_ defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: didComplete)
        defaults.set(false, forKey: didShowCoachMark)
        defaults.set(false, forKey: didShowExtras)
    }
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
    /// The stretch approaches this but never reaches it.
    static let maxStretch: Double = 220
    /// The blob follows the finger 1:1 up to here, then resists.
    static let linearZone: Double = 90
    /// Released with a projected end at or beyond this (points of stretch), the
    /// orb detaches; short of it, the pull springs back.
    static let commitDistance: Double = 120

    /// Maps raw finger travel to the on-screen stretch: 1:1 at first, then an
    /// exponential approach to `maxStretch`.
    static func rubberBand(_ translation: Double) -> Double {
        guard translation > 0 else { return 0 }
        if translation <= linearZone { return translation }
        let soft = maxStretch - linearZone
        return linearZone + soft * (1 - exp(-(translation - linearZone) / soft))
    }

    /// The finger travel that produces `stretch`, so a new drag can pick up a
    /// blob that is still retracting without a jump.
    static func inverseRubberBand(_ stretch: Double) -> Double {
        guard stretch > 0 else { return 0 }
        if stretch <= linearZone { return stretch }
        let soft = maxStretch - linearZone
        let ratio = min((stretch - linearZone) / soft, 0.999_999)
        return linearZone - soft * log(1 - ratio)
    }

    /// Where a release would come to rest, from the stretch and its velocity (points per second).
    static func projectedEnd(stretch: Double, velocity: Double) -> Double {
        Easing.project(position: stretch, velocity: velocity)
    }

    static func shouldCommit(projectedEnd: Double) -> Bool {
        projectedEnd >= commitDistance
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    @Published private(set) var step: OnboardingStep
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
    init(startingAt step: OnboardingStep = .pull, onFinish: @escaping (OnboardingFinishReason) -> Void = { _ in }) {
        self.step = step
        self.onFinish = onFinish
    }

    /// The camera step after Scan: the photo is frozen in the orb's window and
    /// waiting for the user to choose a spot. There is no separate step for it.
    var isPhotoFrozen: Bool { step == .camera && capturedImage != nil }

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
