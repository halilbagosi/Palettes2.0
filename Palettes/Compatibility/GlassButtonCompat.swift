//
//  GlassButtonCompat.swift
//  Palettes
//
//  Availability shim for the iOS 26 glass button styles. Any surrounding `.tint`
//  still applies in both paths.
//

import SwiftUI

extension View {
    /// `.glass` / `.glassProminent` button style on iOS 26+, `.bordered` /
    /// `.borderedProminent` on earlier systems.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}

/// Frosted capsule button for systems without the glass button style.
private struct MaterialCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay { Capsule().stroke(.white.opacity(0.18), lineWidth: 0.75) }
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension View {
    /// Secondary capsule button: `.glass` on iOS 26+ (never `.glassProminent`,
    /// which is always accent-tinted), a material capsule on earlier systems.
    @ViewBuilder
    func glassCapsuleButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(MaterialCapsuleButtonStyle())
        }
    }
}

/// Full-width capsule with a quiet press: a thin material, a hairline rim and a
/// 0.97 scale on touch-down. Used before iOS 26; the label supplies its text only.
private struct PressableCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75) }
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}

extension View {
    /// The onboarding primary button: a 54 pt, full-width (up to 340) glass capsule.
    /// `.glass` on iOS 26 (never `.glassProminent`, which is always accent-tinted),
    /// `PressableCapsuleStyle` on earlier systems.
    @ViewBuilder
    func glassPrimaryButton() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .frame(maxWidth: 340)
                .frame(height: 54)
        } else {
            buttonStyle(PressableCapsuleStyle())
                .frame(maxWidth: 340)
                .frame(height: 54)
        }
    }
}
