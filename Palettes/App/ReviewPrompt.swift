//
//  ReviewPrompt.swift
//  Palettes
//
//  When to ask for an App Store rating. The system owns the prompt itself
//  (and shows it at most three times a year, or not at all if the user has
//  turned rating requests off); this only picks a good moment to ask.
//

import SwiftUI
import StoreKit

nonisolated enum ReviewPrompt {
    /// The app version the prompt was last requested for.
    static let lastVersionKey = "reviewPromptLastVersion"
    /// A user with this many palettes has made the app theirs.
    static let minimumPalettes = 3

    /// Ask right after the user saves a palette, once they have a few, and
    /// only once per app version. A jump of more than one palette is an
    /// iCloud import or a merge, not a save.
    static func shouldAsk(previousCount: Int, count: Int, lastAskedVersion: String?, version: String) -> Bool {
        count == previousCount + 1
            && count >= minimumPalettes
            && lastAskedVersion != version
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

extension View {
    /// Requests an App Store rating after a palette is saved (see
    /// `ReviewPrompt.shouldAsk`). `isReady` is false while something
    /// (onboarding, Settings) covers the screen.
    func reviewPrompt(paletteCount: Int, isReady: Bool) -> some View {
        modifier(ReviewPromptModifier(paletteCount: paletteCount, isReady: isReady))
    }
}

private struct ReviewPromptModifier: ViewModifier {
    let paletteCount: Int
    let isReady: Bool

    @Environment(\.requestReview) private var requestReview
    @AppStorage(ReviewPrompt.lastVersionKey) private var lastAskedVersion = ""
    @State private var pending: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onChange(of: paletteCount) { old, new in
            let version = ReviewPrompt.currentVersion
            guard isReady, ReviewPrompt.shouldAsk(
                previousCount: old, count: new,
                lastAskedVersion: lastAskedVersion.isEmpty ? nil : lastAskedVersion,
                version: version) else { return }
            pending?.cancel()
            pending = Task {
                // Let the save sheet close and its toast land first.
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                lastAskedVersion = version
                requestReview()
            }
        }
    }
}
