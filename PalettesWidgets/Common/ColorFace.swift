//
//  ColorFace.swift
//  PalettesWidgets
//
//  One colour filling the widget. Small: name top-left, copy bottom-left.
//  Medium: name with hex and RGB beneath, copy bottom-right. Used by the
//  Color and Color of the Day widgets.
//

import SwiftUI
import WidgetKit

struct ColorFace: View {
    let swatch: WidgetSnapshot.Swatch
    let family: WidgetFamily
    var caption: String? = nil
    var copied: Bool = false

    private var onLight: Bool { HexRGB.isLight(swatch.hex) }
    private var foreground: Color { .widgetForeground(onLight: onLight) }
    private var copy: CopyButton {
        CopyButton(target: .color(id: swatch.id, hex: swatch.hex), onLight: onLight, copied: copied)
    }

    private var rgbText: String {
        guard let c = HexRGB.components(swatch.hex) else { return "" }
        return "R \(c.r)  G \(c.g)  B \(c.b)"
    }

    var body: some View {
        ZStack {
            SwatchStrip(hexes: [swatch.hex])
            if family == .systemMedium { medium } else { small }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let caption { WidgetCaption(text: caption, onLight: onLight) }
            Text(swatch.name)
                .font(.headline)
                .lineLimit(2)
                .foregroundStyle(foreground)
            Spacer(minLength: 0)
            if CopyButton.isAvailable(in: family) { copy }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let caption { WidgetCaption(text: caption, onLight: onLight) }
            Text(swatch.name)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(foreground)
            Text(swatch.hex.uppercased())
                .font(.subheadline.monospaced())
                .foregroundStyle(foreground.opacity(0.85))
            Text(rgbText)
                .font(.caption.monospaced())
                .foregroundStyle(foreground.opacity(0.75))
            Spacer(minLength: 0)
            HStack {
                Spacer()
                copy
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
    }
}
