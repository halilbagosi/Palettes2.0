//
//  OnboardingModel.swift
//  Palettes
//
//  Pure state for the first-launch onboarding: the step machine, camera
//  permission fallback, and the color the user scans. No UI or framework
//  dependencies beyond UserDefaults, so it is fully unit-testable.
//

import Foundation
import Combine

enum OnboardingStep: Int, CaseIterable {
    case pull, orb, camera, adjust, generate, detail, extras
}

/// Camera availability as onboarding sees it, decoupled from AVFoundation.
enum OnboardingCameraAccess {
    case notDetermined, authorized, denied, restricted
    /// No capture device (e.g. the simulator).
    case unavailable
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

    static func shouldCommit(translation: Double) -> Bool {
        translation >= commitThreshold
    }
}

@MainActor
final class OnboardingModel: ObservableObject {
    /// Per-device flag read by `MyApp` via `@AppStorage`.
    static let completionKey = "didCompleteOnboarding"

    @Published private(set) var step: OnboardingStep = .pull
    @Published private(set) var isFinished = false
    @Published var cameraAccess: OnboardingCameraAccess = .notDetermined
    /// Sampled color, 0...255 per channel; set once the user scans.
    @Published var scannedRGB: (r: Double, g: Double, b: Double)?
    /// Adjustment slider positions, 0.5 = unchanged.
    @Published var brightness = 0.5
    @Published var saturation = 0.5

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Denied, restricted, or missing cameras route to the photo/sample fallback.
    var usesPhotoFallback: Bool {
        switch cameraAccess {
        case .denied, .restricted, .unavailable: true
        case .notDetermined, .authorized: false
        }
    }

    func advance() {
        guard !isFinished else { return }
        if let next = OnboardingStep(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish()
        }
    }

    func skip() {
        finish()
    }

    private func finish() {
        guard !isFinished else { return }
        defaults.set(true, forKey: Self.completionKey)
        isFinished = true
    }
}
