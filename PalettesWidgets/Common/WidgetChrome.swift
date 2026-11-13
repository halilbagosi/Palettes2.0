//
//  WidgetChrome.swift
//  PalettesWidgets
//
//  Small pieces every widget shares. `onLight` is HexRGB.isLight of the
//  colour underneath: dark marks on light colours, white on dark.
//

import SwiftUI
import WidgetKit

extension Color {
    static func widgetForeground(onLight: Bool) -> Color {
        onLight ? .black.opacity(0.82) : .white
    }
}

/// Nothing to show yet. The whole widget opens the library.
struct EmptyWidgetView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "swatchpalette")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(WidgetLink.library.url)
    }
}

struct NameCapsule: View {
    let text: String
    let onLight: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(Color.widgetForeground(onLight: onLight))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(onLight ? Color.white.opacity(0.45) : Color.black.opacity(0.22), in: Capsule())
    }
}

/// A round control that imitates the app's glass buttons. Widgets can't
/// draw the real glass material.
struct GlassCircle: View {
    let symbol: String
    let onLight: Bool
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(Color.widgetForeground(onLight: onLight))
            .frame(width: size, height: size)
            .background(onLight ? Color.white.opacity(0.5) : Color.white.opacity(0.24), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(onLight ? 0.7 : 0.4), lineWidth: 0.5))
    }
}

/// "Today" and similar labels on a swatch.
struct WidgetCaption: View {
    let text: String
    let onLight: Bool

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .lineLimit(1)
            .foregroundStyle(Color.widgetForeground(onLight: onLight))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            // Same pill as NameCapsule, so it reads on any colour.
            .background(onLight ? Color.white.opacity(0.45) : Color.black.opacity(0.22), in: Capsule())
    }
}
