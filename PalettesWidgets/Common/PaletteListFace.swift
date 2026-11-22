//
//  PaletteListFace.swift
//  PalettesWidgets
//

import SwiftUI
import WidgetKit

/// Bands across the top half; name, an optional caption (Palette of the Day
/// passes "Today") and one row per color below. Shared by the large Palette
/// and Palette of the Day widgets.
struct PaletteListFace: View {
    let palette: WidgetSnapshot.Palette
    var caption: String? = nil

    static let maxRows = 6

    /// All rows when they fit; otherwise `maxRows` and a "+N more" line.
    static func shownCount(total: Int) -> Int { min(total, maxRows) }

    private var shownCount: Int { Self.shownCount(total: palette.hexCodes.count) }

    var body: some View {
        VStack(spacing: 0) {
            SwatchStrip(hexes: palette.hexCodes)
                .frame(minHeight: 48, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(palette.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if let caption {
                        Text(caption.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(0..<shownCount, id: \.self) { index in
                    row(hex: palette.hexCodes[index], name: name(at: index))
                }
                if palette.hexCodes.count > shownCount {
                    Text("+\(palette.hexCodes.count - shownCount) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            // The text block takes the height it needs; the bands get the rest.
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The color's name, or nil when missing or empty.
    private func name(at index: Int) -> String? {
        guard palette.colorNames.indices.contains(index) else { return nil }
        let name = palette.colorNames[index]
        return name.isEmpty ? nil : name
    }

    private func row(hex: String, name: String?) -> some View {
        HStack(spacing: 8) {
            SwatchStrip(hexes: [hex])
                .frame(width: 14, height: 14)
                .clipShape(Circle())
            if let name {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            Text(hex.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
