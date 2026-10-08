//
//  LiquidGlassCompat.swift
//  Palettes
//
//  Availability shims for the iOS 26 Liquid Glass APIs. On iOS 26+ these call the
//  real APIs unchanged; on iOS 17–25 they fall back to a frosted material of the
//  same shape so the layout and framing stay identical.
//

import SwiftUI

/// Parity with the `Glass` variants the app uses.
enum LiquidGlassStyle {
    case regular
    case clear
    case interactive
}

extension View {
    /// iOS 26 liquid glass, or a frosted-material equivalent on earlier systems.
    @ViewBuilder
    func liquidGlass<S: Shape>(_ style: LiquidGlassStyle = .regular, in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            switch style {
            case .regular:
                glassEffect(.regular, in: shape)
            case .clear:
                glassEffect(.clear, in: shape)
            case .interactive:
                glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            switch style {
            case .clear:
                // Clear glass mostly refracts the background; keep it see-through
                // with just a hairline rim.
                overlay { shape.stroke(.white.opacity(0.18), lineWidth: 0.75) }
            case .regular, .interactive:
                background(.ultraThinMaterial, in: shape)
                    .overlay { shape.stroke(.white.opacity(0.12), lineWidth: 0.5) }
            }
        }
    }
}

/// `GlassEffectContainer` on iOS 26+, a passthrough on earlier systems.
struct GlassContainer<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
