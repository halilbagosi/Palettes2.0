//
//  OnboardingStyle.swift
//  Palettes
//
//  The onboarding visual system: background, ambient field, the blur text
//  transition, title/subtitle, and the primary, secondary and Skip buttons.
//

import SwiftUI

// MARK: - Background

struct OnboardingBackground: View {
    /// 0...1, the ambient field's opacity. Fades in as the orb detaches.
    var ambient: Double
    /// Tones of the picked color; empty before a color is picked.
    var tint: [Color] = []

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Darker than systemBackground's dark so the island's black goo stays visible.
            (colorScheme == .dark ? Color(white: 0.12) : Color(.systemBackground))
            Group {
                if tint.isEmpty {
                    LiquidGradientView(intensity: 0.25)
                        .transition(.blurBridge)
                        .id("neutral")
                } else {
                    LiquidGradientView(intensity: 0.4, colors: tint)
                        .transition(.blurBridge)
                        .id("tinted")
                }
            }
            .opacity(0) // The stage stays plain, like the reference; the bubble carries the look.
            .animation(.easeInOut(duration: 0.6), value: tint.isEmpty)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Transitions

/// Opacity plus a blur of `radius`; with `rise`, a vertical offset too. The
/// blur bridges the two states so a crossfade reads as one thing changing.
struct BlurFade: Transition {
    var radius: CGFloat = 6
    var rise: CGFloat = 6

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : radius)
            // In: from below. Out: upward.
            .offset(y: phase == .willAppear ? rise : (phase == .didDisappear ? -rise : 0))
    }
}

extension Transition where Self == BlurFade {
    /// Step text: 6 pt blur, 6 pt of travel.
    static var blurFade: BlurFade { BlurFade() }
    /// Background and window swaps: blur only, no travel.
    static var blurBridge: BlurFade { BlurFade(radius: 6, rise: 0) }
}

// MARK: - Text

/// Step copy in the app's own voice: a bold rounded title, the same face as
/// generated palette names, over a softer, roomier subtitle.
struct OnboardingStepText: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 310)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small glass chip above a step's title naming the moment ("Welcome",
/// "Look around"), so each step opens with a friendly cue in the same glass
/// as the app's controls.
struct OnboardingEyebrow: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .foregroundStyle(.secondary)
        }
        .font(.system(.footnote, design: .rounded).weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .liquidGlass(.regular, in: Capsule())
        .accessibilityHidden(true)
    }
}

// MARK: - Step content

/// Everything one step puts on screen below the orb. The coordinator lays it
/// out: text and body in the scrolling region, the buttons pinned at the bottom.
struct OnboardingStepContent {
    struct Primary {
        var title: String
        var systemImage: String? = nil
        var isEnabled = true
        var action: () -> Void
    }

    struct Secondary {
        var view: AnyView

        static func button(_ title: String, _ action: @escaping () -> Void) -> Secondary {
            Secondary(view: AnyView(OnboardingSecondaryButton(title: title, action: action)))
        }
    }

    struct Eyebrow {
        var title: String
        var systemImage: String
    }

    /// Changes when the step's text should cross-fade.
    var key: String
    var eyebrow: Eyebrow? = nil
    var title: String? = nil
    var subtitle: String? = nil
    var body: AnyView? = nil
    var primary: Primary? = nil
    var secondary: Secondary? = nil
}

// MARK: - Buttons

struct OnboardingPrimaryButton: View {
    var title: String
    var systemImage: String?
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentTransition(.opacity)
        }
        .glassPrimaryButton()
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.25), value: title)
    }
}

/// Plain text button with a 44 pt hit area.
struct OnboardingSecondaryButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }
}

struct OnboardingSkipButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Skip")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .liquidGlass(.interactive, in: Capsule())
                // The visible capsule is 30 pt; the touch target is not.
                .padding(7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Sits in a fixed slot above the orb; very large text would overlap it.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityLabel("Skip onboarding")
    }
}
