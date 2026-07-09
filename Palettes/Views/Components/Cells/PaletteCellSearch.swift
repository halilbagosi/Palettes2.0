//
//  PaletteCellSearch.swift
//  Palettes
//
//  Created by Halil Bagosi on 24.2.26.
//

import SwiftUI

/// Compact full-bleed palette row for search and browse: stripes fill the
/// card with the name and color count floating as liquid glass pills.
struct PaletteCellSearch: View {
    let paletteName: String
    let colors: [Color]
    var highlight: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 0) {
                if colors.isEmpty {
                    Rectangle().fill(.quaternary)
                } else {
                    ForEach(colors.indices, id: \.self) { i in
                        Rectangle().fill(colors[i])
                    }
                }
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Text(highlightedText(paletteName, matching: highlight))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: .capsule)

                    Spacer(minLength: 0)

                    HStack(spacing: 4) {
                        Text("\(colors.count)")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassEffect(.regular, in: .capsule)
                }
            }
            .padding(8)
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        PaletteCellSearch(paletteName: "Midnight Ocean", colors: [.blue, .indigo, .black, .cyan, .teal, .blue, .purple, .black])
        PaletteCellSearch(paletteName: "Sunset Glow", colors: [.red, .orange, .yellow, .pink, .orange, .red, .yellow, .pink])
        PaletteCellSearch(paletteName: "Forest Floor", colors: [.green, .brown, .mint, .cyan, .green, .brown, .mint, .gray])
    }
    .padding()
}
