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
        return value > 1 ? 1 / value : 1
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

    /// True when the launch argument is present (DEBUG builds only).
    static var isActive: Bool {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "onboardingStart") != nil
        #else
        return false
        #endif
    }
}
