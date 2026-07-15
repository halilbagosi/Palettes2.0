//
//  PaletteCell.swift
//  Palettes
//

import SwiftUI

/// Full-bleed palette card: the colors fill the card edge to edge as vertical
/// stripes, with the name, a copy action, and a View action floating over
/// them as liquid glass pills. Tapping the card opens the palette.
struct PaletteCell: View {
    let paletteName: String
    let colors: [Color]
    var onViewPalette: () -> Void = {}
    var onCopy: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // The palette itself is the card
            HStack(spacing: 0) {
                if colors.isEmpty {
                    Rectangle().fill(.quaternary)
                } else {
                    ForEach(colors.indices, id: \.self) { i in
                        Rectangle().fill(colors[i])
                    }
                }
            }

            // Floating glass layer: name pill + copy + view pills
            GlassContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Text(paletteName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .liquidGlass(.regular, in: .capsule)

                    Spacer(minLength: 0)

                    viewButton

                    if let onCopy {
                        copyButton(onCopy)
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { onViewPalette() }
    }

    private var viewButton: some View {
        Button(action: onViewPalette) {
            Text("View")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .capsule)
    }

    private func copyButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .circle)
        .accessibilityLabel("Copy HEX")
    }
}

#Preview("6 colors") {
    PaletteCell(paletteName: "Summer Palette", colors: [.red, .orange, .yellow, .green, .blue, .purple], onCopy: {})
        .padding()
}

#Preview("2 colors") {
    PaletteCell(paletteName: "Duo", colors: [.blue, .orange], onCopy: {})
        .padding()
}

#Preview("8 colors") {
    PaletteCell(paletteName: "Ocean", colors: [.blue, .indigo, .black, .cyan, .teal, .blue, .purple, .black], onCopy: {})
        .padding()
}
