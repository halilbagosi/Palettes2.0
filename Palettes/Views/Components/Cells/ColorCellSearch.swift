//
//  ColorCellSearch.swift
//  Palettes
//
//  Created by Halil Bagosi on 24.2.26.
//

import SwiftUI

/// Compact full-bleed color tile for search and browse: the color fills the
/// tile with the name and hex floating in a liquid glass pill.
struct ColorCellSearch: View {
    let colorName: String
    let hexCode: String
    let color: Color
    var highlight: String = ""
    /// When provided, a copy button is shown in the trailing corner.
    var onCopy: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(color.gradient)

            GlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(highlightedText(colorName, matching: highlight))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        Text(highlightedText(hexCode, matching: highlight))
                            .font(.system(.caption2, design: .monospaced).weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .liquidGlass(.regular, in: .capsule)

                    if let onCopy {
                        Spacer(minLength: 0)
                        copyButton(onCopy)
                    }
                }
                .padding(8)
            }
        }
        .frame(height: 118)
        // Card radius = pill capsule radius (~20) + 8pt inset, so the pill
        // sits concentric with the card corner.
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func copyButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .circle)
        .accessibilityLabel("Copy HEX")
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 12)], spacing: 12) {
        ColorCellSearch(colorName: "Maroon", hexCode: "#800000", color: Color(red: 128/255.0, green: 0, blue: 0))
        ColorCellSearch(colorName: "Electric Blue", hexCode: "#007AFF", color: Color(red: 0.00, green: 0.48, blue: 1.00))
        ColorCellSearch(colorName: "Neon Lime", hexCode: "#CCFF00", color: Color(red: 0.8, green: 1.0, blue: 0.0))
        ColorCellSearch(colorName: "Peach", hexCode: "#FFCC99", color: Color(red: 1.0, green: 0.8, blue: 0.6))
    }
    .padding()
}
