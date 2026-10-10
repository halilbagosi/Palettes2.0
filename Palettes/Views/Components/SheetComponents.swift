//
//  SheetComponents.swift
//  Palettes
//
//  Building blocks shared by the create/edit sheets so they read as one family
//  with the detail pages: the color wash, the palette strip, and a legible ink.
//

import SwiftUI

/// The backdrop of `ColorDetailView` and `ColorEditView`: the color at the top,
/// fading into a near-neutral tint of it. The system background while there is
/// no color yet.
struct ColorWashBackground: View {
    var color: Color?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let color {
                LinearGradient(
                    colors: [color.opacity(0.8), end(for: color)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color(.systemBackground)
            }
        }
        .ignoresSafeArea()
    }

    private func end(for color: Color) -> Color {
        let (h, s, _) = color.hsbComponents
        if colorScheme == .dark {
            return Color(hue: h, saturation: s, brightness: 0.08)
        } else {
            return Color(hue: h, saturation: s * 0.08, brightness: 0.97)
        }
    }
}

/// A palette as one rounded strip of equal segments (the detail page's hero
/// strip, shorter). A dashed outline while the palette is empty.
struct PaletteStrip: View {
    let colors: [Color]
    var height: CGFloat = 56
    var cornerRadius: CGFloat = 16

    var body: some View {
        Group {
            if colors.isEmpty {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            } else {
                HStack(spacing: 0) {
                    ForEach(colors.indices, id: \.self) { index in
                        Rectangle()
                            .fill(colors[index])
                            // Overlap neighbors a hairline so antialiasing
                            // can't show a background seam mid-animation.
                            .padding(.horizontal, -0.5)
                    }
                }
                // Gaps the spring briefly opens show this, not the sheet.
                .background(colors.last ?? Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.3), value: colors.count)
        .accessibilityHidden(true)
    }
}

extension Color {
    /// Black or white, whichever reads on this color.
    var legibleInk: Color {
        let rgb = rgbComponents
        let linear = [rgb.r, rgb.g, rgb.b].map { value -> Double in
            let c = min(max(value / 255, 0), 1)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        return luminance > 0.18 ? .black : .white
    }
}
