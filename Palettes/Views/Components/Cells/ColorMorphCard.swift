//
//  ColorMorphCard.swift
//  Palettes
//
//  A single colour card that fills whatever frame it is given and morphs its
//  glass overlays between the library's normal and compact presentations. The
//  colored base is one persistent layer, so an animated frame change reads as a
//  smooth resize rather than a cross-dissolve. Pairs with `MorphingCardGrid`,
//  which owns the frame animation; this view only fades its two pill layouts.
//

import SwiftUI

struct ColorMorphCard: View {
    let colorName: String
    let hexCode: String
    let color: Color
    var isCompact: Bool
    /// Opens the colour detail view; shown as a "View" pill in the normal layout.
    var onView: (() -> Void)? = nil
    /// Copies the HEX; wired to the copy button in both layouts.
    var onCopy: (() -> Void)? = nil

    var body: some View {
        Rectangle()
            .fill(color.gradient)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                namePill
                    .padding(12)
                    .opacity(isCompact ? 0 : 1)
            }
            .overlay(alignment: .bottom) {
                regularBottomBar
                    .padding(12)
                    .opacity(isCompact ? 0 : 1)
            }
            .overlay(alignment: .bottomLeading) {
                compactBar
                    .opacity(isCompact ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    // MARK: - Normal layout: floating name (top) + hex/View/copy bar (bottom)

    private var namePill: some View {
        Text(colorName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlass(.regular, in: .capsule)
    }

    private var regularBottomBar: some View {
        GlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                Text(hexCode)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .liquidGlass(.regular, in: .capsule)

                Spacer(minLength: 0)

                if let onView {
                    Button(action: onView) {
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

                copyButton(diameter: 38)
            }
        }
    }

    // MARK: - Compact layout: name + hex stacked, trailing copy

    private var compactBar: some View {
        GlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(colorName)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                    Text(hexCode)
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .liquidGlass(.regular, in: .capsule)

                Spacer(minLength: 0)

                copyButton(diameter: 40)
            }
            .padding(8)
        }
    }

    private func copyButton(diameter: CGFloat) -> some View {
        Button {
            onCopy?()
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .circle)
        .accessibilityLabel("Copy HEX")
    }
}
