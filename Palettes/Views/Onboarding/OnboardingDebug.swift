//
//  OnboardingDebug.swift
//  Palettes
//
//  DEBUG-only launch argument for jumping straight to an onboarding step, for
//  screenshots and verification:
//
//      -onboardingStart <pull|camera|picked|adjust|generate>
//
//  Onboarding is presented at that step using the sample image, even when it was
//  completed before. Release builds ignore it.
//

import Foundation

enum OnboardingDebug {
    /// The step names the launch argument and the Settings picker accept.
    static let stepNames = ["pull", "camera", "picked", "adjust", "generate"]
    static let slowMoToggleKey = "onboardingSlowMoOn"
    private static let startKey = "onboardingStart"

    struct Start {
        let name: String

        var step: OnboardingStep {
            switch name {
            case "camera", "picked": .camera
            case "adjust": .adjust
            case "generate": .generate
            default: .pull
            }
        }

        /// Seeds the model with the sample image so later steps have a color.
        @MainActor
        func prepare(_ model: OnboardingModel) {
            switch name {
            case "picked", "adjust", "generate":
                model.capturedImage = OnboardingSampleImage.shared
            default:
                break
            }
        }
    }

    /// The requested start, or the normal one (the pull).
    static var start: Start {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "onboardingStart") { return Start(name: name) }
        #endif
        return Start(name: "pull")
    }

    /// `-onboardingSlowMo <factor>`: slows the morph's springs by this factor so
    /// intermediate frames can be captured. 1 otherwise.
    static var timeScale: Double {
        #if DEBUG
        let value = UserDefaults.standard.double(forKey: "onboardingSlowMo")
        if value > 1 { return 1 / value }
        // The Settings toggle: quarter speed.
        return UserDefaults.standard.bool(forKey: slowMoToggleKey) ? 0.25 : 1
        #else
        return 1
        #endif
    }

    /// `-onboardingPullHold <points>`: holds the pull at this stretch, for still frames of the neck.
    static var pullHold: Double? {
        #if DEBUG
        let value = UserDefaults.standard.double(forKey: "onboardingPullHold")
        return value > 0 ? value : nil
        #else
        return nil
        #endif
    }

    /// `-onboardingAutoBegin YES`: after a moment, begins as if Begin were tapped (the
    /// fade path), for capturing it on devices the simulator tool can't drive.
    static var autoBegin: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "onboardingAutoBegin")
        #else
        return false
        #endif
    }

    /// `-onboardingGlassLab YES`: shows a grid of glass-orb variants instead of onboarding.
    static var glassLab: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "onboardingGlassLab")
        #else
        return false
        #endif
    }

    /// True when the app was launched with `-onboardingStart` or `-onboardingGlassLab` (DEBUG
    /// builds only). A start recorded by Settings does not count: that one goes through the
    /// normal replay presentation.
    static var isLaunchArgument: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-onboardingStart") || args.contains("-onboardingGlassLab")
        #else
        return false
        #endif
    }

    // MARK: Apple Intelligence

    /// Which onboarding path to take, regardless of the device: with Apple
    /// Intelligence (pick a color, generate around it) or without (palette
    /// straight from the photo).
    enum AIOverride: String, CaseIterable, Identifiable {
        case automatic, on, off

        var id: String { rawValue }

        var label: String {
            switch self {
            case .automatic: "Automatic"
            case .on: "On"
            case .off: "Off"
            }
        }
    }

    /// Settings picker key; `-onboardingAI on|off` sets it from the launch arguments.
    static let aiOverrideKey = "onboardingAI"

    static var aiOverride: AIOverride {
        #if DEBUG
        return UserDefaults.standard.string(forKey: aiOverrideKey).flatMap(AIOverride.init) ?? .automatic
        #else
        return .automatic
        #endif
    }

    // MARK: Settings (DEBUG "Try Onboarding")

    /// Records the step for the next presentation. Settings then asks the replay
    /// coordinator to present onboarding as a normal replay would.
    static func requestFromSettings(start name: String) {
        #if DEBUG
        UserDefaults.standard.set(name, forKey: startKey)
        #endif
    }

    /// Clears a start written by Settings so a normal launch never begins mid-flow.
    /// A launch argument lives in the argument domain and is unaffected.
    static func clearSettingsRequest() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: startKey)
        #endif
    }
}
