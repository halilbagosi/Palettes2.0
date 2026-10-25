//
//  SwatchEdge.swift
//  Palettes
//

import SwiftUI

/// The soft edge every color swatch, palette card and color card shares, so
/// colors close to the background (near-white in light mode, near-black in
/// dark mode) still read as a separate shape: a faint drop shadow in light
/// mode, a faint light glow in dark mode.
///
/// The edge is drawn by a background-filled copy of `shape` behind it, not
/// by shadowing the content: that keeps it to one cheap blur per card (glass
/// pills and overlays don't each get their own), and it sits outside any
/// `clipShape` on the content so it isn't sliced off. Containers need about
/// 10pt of padding around a swatch to show the whole edge.
struct SwatchEdge<S: Shape>: ViewModifier {
    let shape: S

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark
        content.background {
            shape
                .fill(.background)
                .shadow(
                    color: isDark ? .white.opacity(0.14) : .black.opacity(0.12),
                    radius: 6,
                    x: 0,
                    y: isDark ? 0 : 3
                )
        }
    }
}

extension View {
    /// Adds the shared soft swatch edge around a view drawn in `shape`.
    func swatchEdge<S: Shape>(_ shape: S) -> some View {
        modifier(SwatchEdge(shape: shape))
    }
}

#Preview("Near-white and near-black") {
    HStack(spacing: 20) {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(white: 0.98))
            .swatchEdge(RoundedRectangle(cornerRadius: 28, style: .continuous))
        Circle()
            .fill(Color(white: 0.03))
            .swatchEdge(Circle())
    }
    .frame(height: 120)
    .padding(40)
}
