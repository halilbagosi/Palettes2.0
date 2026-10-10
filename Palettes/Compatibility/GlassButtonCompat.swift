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
