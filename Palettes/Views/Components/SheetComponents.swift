//
//  SheetComponents.swift
//  Palettes
//
//  Building blocks shared by the create/add sheets so they read as one family
//  with the detail pages: the same section captions, color wash, hero window,
//  palette strip and card radii.
//

import SwiftUI

/// Secondary semibold caption above a section, as on the detail pages.
struct SheetSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }
}

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

/// The large rounded color window from `ColorDetailView`, with the hex in a
/// capsule. A dashed placeholder while there's no color yet.
struct SwatchHero: View {
    var color: Color?
    var hex: String?
    var placeholder: String = "Your color will appear here"
    var height: CGFloat = 180

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let color {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(color.gradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)

                if let hex {
                    let ink = color.legibleInk
                    Text(hex)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .foregroundStyle(ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ink.opacity(0.12), in: Capsule())
                        .padding(14)
                }
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .overlay {
                        Label(placeholder, systemImage: "eyedropper.halffull")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                    }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hex.map { "Preview, \($0)" } ?? placeholder)
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

/// Name field on a glass card, with an optional swatch of the color it names.
struct ColorNameField: View {
    var color: Color?
    @Binding var name: String
    var placeholder: String = "Color Name"

    var body: some View {
        HStack(spacing: 12) {
            if let color {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.gradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }

            TextField(placeholder, text: $name)
                .font(.system(size: 18, weight: .medium))
                .submitLabel(.done)

            if !name.isEmpty {
                Button {
                    name = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear name")
            }
        }
        .padding(color == nil ? 16 : 10)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal)
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
