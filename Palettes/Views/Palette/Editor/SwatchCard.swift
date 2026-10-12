//
//  SwatchCard.swift
//  Palettes
//
//  The library's compact color card, about a third of the sheet wide so three
//  sit side by side: the color fills it, with the name and HEX on glass and a
//  small control in its corner. Added Colors and the Library source both use it.
//

import SwiftUI

/// Three cards to a row.
enum SwatchCardGrid {
    static let spacing: CGFloat = 8
    static let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
}

struct SwatchCard<Accessory: View>: View {
    let color: Color
    let name: String
    /// The line under the name: the HEX, or a short status.
    let hex: String
    var role: String? = nil
    /// Drawn in the card's top-trailing corner.
    @ViewBuilder var accessory: () -> Accessory

    static var height: CGFloat { 96 }

    var body: some View {
        // The library's compact color card, without its copy button: the
        // color fills the card, the name and HEX sit on glass at its foot.
        Rectangle()
            .fill(color.gradient)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .overlay(alignment: .topLeading) {
                if let role, !role.isEmpty {
                    Text(role)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .liquidGlass(.regular, in: .capsule)
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) { accessory() }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name.isEmpty ? "Untitled" : name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(hex)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .liquidGlass(.regular, in: .capsule)
                .padding(6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

/// A card in the editor's Added Colors grid: tap to edit, the minus removes.
struct PaletteColorCard: View {
    let color: PaletteColor
    var onEdit: () -> Void
    var onRemove: () -> Void

    var body: some View {
        SwatchCard(color: color.color, name: color.name, hex: color.hex.uppercased(), role: color.role) {
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.red.opacity(0.85))
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(color.name.isEmpty ? "Untitled" : color.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Edit", onEdit)
        .accessibilityLabel("\(color.name.isEmpty ? "Untitled" : color.name), \(color.hex)")
        .accessibilityValue(color.role ?? "")
    }
}

#Preview {
    LazyVGrid(columns: SwatchCardGrid.columns, spacing: SwatchCardGrid.spacing) {
        PaletteColorCard(
            color: PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue", role: "Primary"),
            onEdit: {}, onRemove: {}
        )
        PaletteColorCard(
            color: PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron"),
            onEdit: {}, onRemove: {}
        )
    }
    .padding()
}
