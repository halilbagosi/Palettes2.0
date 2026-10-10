//
//  PaletteBandCard.swift
//  Palettes
//

import SwiftUI

/// A palette being shaped, as one tall card with a full-width band per color
/// and its name and hex in an ink that reads on it: the look of the Generate
/// result, so a hand-made palette and a generated one feel the same. Tap a
/// band to edit it; remove it from its trailing button or context menu.
struct PaletteBandCard: View {
    let colors: [PaletteColor]
    var onEdit: (Int) -> Void
    var onRemove: (Int) -> Void
    var onMove: ((_ from: Int, _ to: Int) -> Void)? = nil

    private var bandHeight: CGFloat {
        colors.count <= 4 ? 80 : (colors.count <= 6 ? 66 : 56)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.element.id) { index, color in
                band(color, at: index)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: colors.count)
    }

    private func band(_ color: PaletteColor, at index: Int) -> some View {
        let ink = color.color.legibleInk
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(color.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(color.hex)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .opacity(0.7)
            }

            Spacer(minLength: 8)

            Button {
                onRemove(index)
            } label: {
                Image(systemName: "minus")
                    .font(.footnote.weight(.bold))
                    .frame(width: 30, height: 30)
                    .background(ink.opacity(0.14), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .foregroundStyle(ink)
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: bandHeight)
        .frame(maxWidth: .infinity)
        .background(color.color)
        .contentShape(Rectangle())
        .onTapGesture { onEdit(index) }
        .contextMenu {
            Button("Edit Color", systemImage: "pencil") { onEdit(index) }
            if let onMove {
                if index > 0 {
                    Button("Move Up", systemImage: "arrow.up") { onMove(index, index - 1) }
                }
                if index < colors.count - 1 {
                    Button("Move Down", systemImage: "arrow.down") { onMove(index, index + 1) }
                }
            }
            Divider()
            Button("Remove", systemImage: "minus.circle", role: .destructive) { onRemove(index) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(color.name), \(color.hex)")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Edits the color")
        .accessibilityAction { onEdit(index) }
        .accessibilityAction(named: "Remove") { onRemove(index) }
    }
}
