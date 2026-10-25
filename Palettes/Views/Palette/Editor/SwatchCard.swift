//
//  SwatchCard.swift
//  Palettes
//
//  The library's compact color card, about a third of the sheet wide so three
//  sit side by side: the color fills it, with the name and HEX on glass and a
//  small control in its corner. The Library source uses it.
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
            .fill(color)
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
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary.opacity(0.7))
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

#Preview {
    LazyVGrid(columns: SwatchCardGrid.columns, spacing: SwatchCardGrid.spacing) {
        SwatchCard(color: Color(hex: "#264653") ?? .gray, name: "Charcoal Blue", hex: "#264653", role: "Primary") {}
        SwatchCard(color: Color(hex: "#E9C46A") ?? .gray, name: "Saffron", hex: "#E9C46A") {}
    }
    .padding()
}
