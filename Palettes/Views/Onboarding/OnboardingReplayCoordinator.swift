//
//  OnboardingReplayCoordinator.swift
//  Palettes
//
//  Carries "replay onboarding" from the Settings sheet to the sheet's
//  presenter, which acts on it in `onDismiss` once the sheet is fully gone.
//

import Foundation
import Combine

@MainActor
final class OnboardingReplayCoordinator: ObservableObject {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    private(set) var isRequested = false

    /// `withAppleIntelligence` replays down the Apple Intelligence path even
    /// where the model can't run.
    func request(withAppleIntelligence: Bool = false) {
        OnboardingPaletteMaker.forcesAI = withAppleIntelligence
        isRequested = true
    }

    /// Returns whether a replay was requested, clearing the request.
    func consume() -> Bool {
        defer { isRequested = false }
        return isRequested
    }
}
