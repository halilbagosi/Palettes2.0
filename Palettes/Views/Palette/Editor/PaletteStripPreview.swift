//
//  PaletteStripPreview.swift
//  Palettes
//
//  The palette as it will look, at the top of the editor. Display only: the
//  colors are edited, removed and reordered in PaletteColorRow under the name.
//

import SwiftUI

struct PaletteStripPreview: View {
    let colors: [PaletteColor]
    /// Bands that are entering as a first fill, each with its place in the
    /// stagger (empty otherwise).
    var entrance: [UUID: Int] = [:]
    /// Take whatever height the container has (at least `height`) instead of
    /// the fixed `height`: the split layout's tall strip.
    var fillsHeight = false

    /// Also the height of the empty preview and of Pick's swatch.
    static let height: CGFloat = 72
    private let cornerRadius: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            ForEach(colors) { entry in
                band(entry)
            }
        }
        .frame(minHeight: Self.height, maxHeight: fillsHeight ? .infinity : Self.height)
        // Clear while bands stagger in, so the last color doesn't fill the strip first.
        .background(entrance.isEmpty ? (colors.last?.color ?? Color.clear) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .swatchEdge(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Palette preview")
        .accessibilityValue(colors.map(\.name).joined(separator: ", "))
    }

    private func band(_ entry: PaletteColor) -> some View {
        let ink = entry.color.legibleInk
        return ZStack(alignment: .bottom) {
            if let role = entry.role, !role.isEmpty {
                Text(role)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ink.opacity(0.15), in: Capsule())
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
        }
        // minWidth 0: a role capsule can't widen its band past its share.
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Overlap neighbors a hairline so antialiasing can't show a seam.
            Rectangle().fill(entry.color).padding(.horizontal, -0.5)
        }
        .firstFillEntrance(index: entrance[entry.id])
    }
}

#Preview {
    PaletteStripPreview(colors: [
        PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue", role: "Primary"),
        PaletteColor(color: Color(hex: "#2A9D8F") ?? .gray, hex: "#2A9D8F", name: "Persian Green"),
        PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron", role: "Accent"),
    ])
    .padding()
}
