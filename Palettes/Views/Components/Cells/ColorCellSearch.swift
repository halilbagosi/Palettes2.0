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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(color.gradient)

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
            .glassEffect(.regular, in: .capsule)
            .padding(8)
        }
        .frame(height: 118)
        // Card radius = pill capsule radius (~20) + 8pt inset, so the pill
        // sits concentric with the card corner.
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
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
