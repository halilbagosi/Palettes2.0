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
            (colorScheme == .dark ? Color(white: 0.09) : Color(.systemBackground))
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
            .opacity(ambient)
            .animation(.easeInOut(duration: 0.6), value: tint.isEmpty)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Orb halo

/// A saturated glow behind the orb. Clear Liquid Glass brightens whatever is behind
/// it, so over the near-white ambient field it renders as a flat white disc; over
/// colored light it reads as a transparent lens that bends the color. The halo
/// travels with the orb.
struct OrbHalo: View {
    var diameter: CGFloat
    var colors: [Color] = []

    var body: some View {
        // The shader's color features scale with its frame, so the frame stays close to the
        // orb's size: the glass then bends a gradient of several colors, not one flat tone.
        // Without custom colors this is the bright iridescent field, whose bands read most
        // clearly as refraction through clear glass.
        let side = max(diameter * 1.55, 1)
        Group {
            if colors.isEmpty {
                LiquidGradientView(intensity: 1)
            } else {
                LiquidGradientView(intensity: 0.9, colors: colors)
            }
        }
        .frame(width: side, height: side)
        .mask(RadialGradient(stops: [.init(color: .black, location: 0),
                                     .init(color: .black, location: 0.55),
                                     .init(color: .clear, location: 1)],
                             center: .center, startRadius: 0, endRadius: side / 2))
            .allowsHitTesting(false)
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

struct OnboardingStepText: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title.weight(.bold))
                .tracking(-0.4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
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

    /// Changes when the step's text should cross-fade.
    var key: String
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
