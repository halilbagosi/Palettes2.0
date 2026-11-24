//
//  WidgetChrome.swift
//  PalettesWidgets
//
//  Small pieces every widget shares. `onLight` is HexRGB.isLight of the
//  colour underneath: dark marks on light colours, white on dark.
//

import SwiftUI
import UIKit
import WidgetKit

extension Color {
    static func widgetForeground(onLight: Bool) -> Color {
        onLight ? .black.opacity(0.82) : .white
    }
}

/// Nothing to show yet. The whole widget opens `link` (the library by default).
struct EmptyWidgetView: View {
    let message: String
    var link: WidgetLink = .library

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
        .widgetURL(link.url)
    }
}

// MARK: - Legibility in clear and tinted modes

/// In the clear and tinted Home Screen styles (`widgetRenderingMode ==
/// .accented`) the system draws all text and shapes in one tint, white in
/// clear mode, whatever colour we set: dark text on a light swatch turns
/// white on light. Only images marked full-colour keep their colours, so the
/// dark backing that keeps text readable there is an image.
struct WidgetScrim: View {
    /// Dark enough that white text on it passes 4.5:1 over a near-white swatch.
    static let opacity: CGFloat = 0.55

    var body: some View {
        Image(uiImage: Self.image)
            .resizable()
            .fullColorInAccentedModes()
            .accessibilityHidden(true)
    }

    private static var image: UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            UIColor.black.withAlphaComponent(opacity).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }
}

private struct AccentedScrim: ViewModifier {
    let onLight: Bool
    let cornerRadius: CGFloat
    @Environment(\.widgetRenderingMode) private var renderingMode

    func body(content: Content) -> some View {
        if renderingMode == .accented && onLight {
            // Grows outward (padding, then the same padding back) so the
            // text stays exactly where it sits in full colour.
            content
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background {
                    WidgetScrim()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .padding(.horizontal, -6)
                .padding(.vertical, -4)
        } else {
            content
        }
    }
}

extension View {
    /// Puts a dark backing behind text on a light swatch, only in the clear
    /// and tinted styles, where the text can't be dark itself.
    func accentedScrim(onLight: Bool, cornerRadius: CGFloat = 8) -> some View {
        modifier(AccentedScrim(onLight: onLight, cornerRadius: cornerRadius))
    }
}

/// The pill behind `NameCapsule` and `WidgetCaption`: light or dark glass in
/// full colour, the image scrim in clear and tinted styles (see `WidgetScrim`).
private struct PillBackground: View {
    let onLight: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .accented {
            WidgetScrim().clipShape(Capsule())
        } else {
            Capsule().fill(onLight ? Color.white.opacity(0.45) : Color.black.opacity(0.22))
        }
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
            .background { PillBackground(onLight: onLight) }
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
            .background { PillBackground(onLight: onLight) }
    }
}
