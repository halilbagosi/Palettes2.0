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
    private(set) var isRequested = false

    func request() {
        isRequested = true
    }

    /// Returns whether a replay was requested, clearing the request.
    func consume() -> Bool {
        defer { isRequested = false }
        return isRequested
    }
}
