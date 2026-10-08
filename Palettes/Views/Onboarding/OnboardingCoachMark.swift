//
//  OnboardingCoachMark.swift
//  Palettes
//
//  The one-time hint on the new palette's detail screen after onboarding.
//  Non-modal: only the hint itself takes touches. It goes away when a color's
//  menu opens (the first long press; `PaletteDetailView` clears the target from
//  the menu's preview) or on a tap on the hint, and never comes back once shown.
//

import SwiftUI

/// Pure show/dismiss rules, kept apart from the view so they are testable.
enum OnboardingCoachMarkLogic {
    /// Show only on the palette onboarding just created, and only once ever.
    static func shouldShow(target: UUID?, paletteID: UUID, alreadyShown: Bool) -> Bool {
        !alreadyShown && target == paletteID
    }
}

extension View {
    /// Hook for `PaletteDetailView`; inert unless onboarding targeted this palette.
    func onboardingCoachMark(for paletteID: UUID) -> some View {
        modifier(OnboardingCoachMarkModifier(paletteID: paletteID))
    }
}

private struct OnboardingCoachMarkModifier: ViewModifier {
    let paletteID: UUID

    @EnvironmentObject private var appData: AppData
    @AppStorage(OnboardingKeys.didShowCoachMark) private var didShow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var presentTask: Task<Void, Never>?

    static let message = "Long press a color for options, or tag it."

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if visible { hint }
            }
            .onAppear { present() }
            .onChange(of: appData.coachMarkPaletteID) { _, target in
                // Cleared elsewhere (the color menu opened): hide with it.
                if target == nil { dismiss() } else { present() }
            }
            .onDisappear {
                presentTask?.cancel()
                if visible { dismiss() }
            }
    }

    private var hint: some View {
        Button(action: dismiss) {
            Label(Self.message, systemImage: "hand.tap")
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        .accessibilityHint("Double tap to dismiss")
    }

    private func present() {
        guard !visible,
              OnboardingCoachMarkLogic.shouldShow(
                target: appData.coachMarkPaletteID, paletteID: paletteID, alreadyShown: didShow)
        else { return }
        presentTask?.cancel()
        presentTask = Task {
            // Let the cover finish dismissing before the hint appears.
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            // Re-check: a long press or navigation may have intervened.
            guard OnboardingCoachMarkLogic.shouldShow(
                target: appData.coachMarkPaletteID, paletteID: paletteID, alreadyShown: didShow) else { return }
            didShow = true
            withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.5, bounce: 0.2)) {
                visible = true
            }
            UIAccessibility.post(notification: .announcement, argument: Self.message)
        }
    }

    private func dismiss() {
        presentTask?.cancel()
        appData.coachMarkPaletteID = nil
        guard visible else { return }
        withAnimation(.easeInOut(duration: 0.25)) { visible = false }
    }
}
