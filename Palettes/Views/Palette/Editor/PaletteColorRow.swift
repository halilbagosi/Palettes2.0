//
//  PaletteColorRow.swift
//  Palettes
//
//  One row of the editor's "Added Colors" list, in the New Palette sheet's
//  glass-row style: swatch, name (with its tag, if any), HEX and RGB, and a
//  red minus to remove. Tapping the row or its swatch edits the color.
//

import SwiftUI

struct PaletteColorRow: View {
    let color: PaletteColor
    var onEdit: () -> Void
    var onRemove: () -> Void

    private var displayName: String {
        color.name.isEmpty ? "Untitled" : color.name
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.color.gradient)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let role = color.role, !role.isEmpty {
                                Text(role)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                            }
                        }

                        HStack(spacing: 6) {
                            Text(color.hex)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                            Text(color.color.rgbString)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(displayName), \(color.hex)")
            .accessibilityValue(color.role ?? "")
            .accessibilityHint("Double-tap to edit")

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(displayName)")
        }
        .padding(10)
        .liquidGlass(.regular, in: .rect(cornerRadius: 14))
    }
}

#Preview {
    VStack(spacing: 8) {
        PaletteColorRow(
            color: PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue", role: "Primary"),
            onEdit: {}, onRemove: {}
        )
        PaletteColorRow(
            color: PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron"),
            onEdit: {}, onRemove: {}
        )
    }
    .padding()
}
