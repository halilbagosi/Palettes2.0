//
//  PaletteMorphCard.swift
//  Palettes
//
//  A single palette card that fills whatever frame it is given and morphs its
//  glass overlays between the library's normal and compact presentations. The
//  colour stripes are one persistent layer, so an animated frame change reads as
//  a smooth resize rather than a cross-dissolve. Pairs with `MorphingCardGrid`,
//  which owns the frame animation; this view only fades its two pill layouts.
//

import SwiftUI

struct PaletteMorphCard: View {
    let paletteName: String
    let colors: [Color]
    var isCompact: Bool
    var isGenerated: Bool = false
    var isFavorite: Bool = false
    var isSelecting: Bool = false
    /// Opens the palette; shown as a "View" pill in the normal layout.
    var onView: (() -> Void)? = nil
    /// Copies the palette's HEX codes; wired to the copy button in both layouts.
    var onCopy: (() -> Void)? = nil

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

            regularBar.opacity(isCompact ? 0 : 1)
            compactBar.opacity(isCompact ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) {
            if isFavorite && !isSelecting {
                favoriteBadge
                    .padding(.top, 12)
                    .padding(.leading, 12)
            }
        }
        .overlay(alignment: .topTrailing) {
            generatedBadge
                .padding(.top, 12)
                .padding(.leading, 12)
                .padding(.trailing, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private var generatedBadge: some View {
        if isGenerated && !isSelecting, #available(iOS 26.0, *) {
            GeneratedBadge(isCompact: isCompact)
        }
    }

    private var favoriteBadge: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
                .offset(y: -1)
        }
        .frame(width: 34, height: 34)
        .liquidGlass(.regular, in: .circle)
    }

    // MARK: - Normal layout: name + View + copy

    private var regularBar: some View {
        GlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                Text(paletteName)
                    .font(.subheadline.weight(.semibold))
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

                if !isSelecting {
                    copyButton(diameter: 38)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Compact layout: name + copy

    private var compactBar: some View {
        GlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                Text(paletteName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .liquidGlass(.regular, in: .capsule)

                Spacer(minLength: 0)

                if !isSelecting {
                    copyButton(diameter: 40)
                }
            }
        }
        .padding(8)
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
