//
//  ColorFace.swift
//  PalettesWidgets
//
//  One colour filling the widget: its name with hex and RGB beneath, top-left,
//  scaled up from small to large. Tapping opens the colour. The Color and
//  Color of the Day widgets use all three sizes.
//

import SwiftUI
import WidgetKit

struct ColorFace: View {
    let swatch: WidgetSnapshot.Swatch
    let family: WidgetFamily
    var caption: String? = nil

    private var onLight: Bool { HexRGB.isLight(swatch.hex) }
    private var foreground: Color { .widgetForeground(onLight: onLight) }

    private var rgbText: String {
        guard let c = HexRGB.components(swatch.hex) else { return "" }
        return "R \(c.r)  G \(c.g)  B \(c.b)"
    }

    var body: some View {
        ZStack {
            SwatchStrip(hexes: [swatch.hex])
            switch family {
            case .systemLarge: large
            case .systemMedium: medium
            default: small
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption { WidgetCaption(text: caption, onLight: onLight) }
            VStack(alignment: .leading, spacing: 2) {
                Text(swatch.name)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(foreground)
                Text(swatch.hex.uppercased())
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.85))
                Text(rgbText)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.75))
            }
            .accentedScrim(onLight: onLight)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption { WidgetCaption(text: caption, onLight: onLight) }
            VStack(alignment: .leading, spacing: 4) {
                Text(swatch.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(foreground)
                Text(swatch.hex.uppercased())
                    .font(.subheadline.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.85))
                Text(rgbText)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.75))
            }
            .accentedScrim(onLight: onLight)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let caption { WidgetCaption(text: caption, onLight: onLight) }
            VStack(alignment: .leading, spacing: 6) {
                Text(swatch.name)
                    .font(.title.weight(.bold))
                    .lineLimit(2)
                    .foregroundStyle(foreground)
                Text(swatch.hex.uppercased())
                    .font(.title3.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.85))
                Text(rgbText)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(foreground.opacity(0.75))
            }
            .accentedScrim(onLight: onLight, cornerRadius: 10)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
    }
}
