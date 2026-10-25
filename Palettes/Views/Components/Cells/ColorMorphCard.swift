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

struct ColorMorphCard: View, Equatable {
    let colorName: String
    let hexCode: String
    let color: Color
    var isCompact: Bool
    var isGenerated: Bool = false
    var isFavorite: Bool = false
    var isSelecting: Bool = false
    /// Copies the HEX; wired to the copy button in both layouts.
    var onCopy: (() -> Void)? = nil

    /// Closures are excluded: callers' closures only read state that is also
    /// reflected in these value fields (e.g. `isSelecting`), so equal values
    /// render and behave identically. Lets `.equatable()` skip body re-runs.
    static func == (lhs: ColorMorphCard, rhs: ColorMorphCard) -> Bool {
        lhs.colorName == rhs.colorName && lhs.hexCode == rhs.hexCode && lhs.color == rhs.color
            && lhs.isCompact == rhs.isCompact && lhs.isGenerated == rhs.isGenerated
            && lhs.isFavorite == rhs.isFavorite && lhs.isSelecting == rhs.isSelecting
            && (lhs.onCopy == nil) == (rhs.onCopy == nil)
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topLeading) {
                if !isCompact {
                    namePill
                        .padding(12)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .topLeading) {
                if isCompact && isFavorite && !isSelecting {
                    favoriteBadge
                        .padding(.top, 12)
                        .padding(.leading, 12)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isCompact {
                    generatedBadge
                        .padding(8)
                } else if !isSelecting {
                    // Generated badge shares the copy button's size and
                    // trailing inset (38pt @ 12) in the regular layout.
                    HStack(spacing: 8) {
                        if isFavorite {
                            favoriteBadge
                        }
                        generatedBadge
                    }
                    .padding(12)
                }
            }
            .overlay(alignment: .bottom) {
                // Only the active layout's glass bar is mounted; the layout
                // toggle cross-fades them via the surrounding animation.
                if isCompact {
                    compactBar
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .transition(.opacity)
                } else {
                    regularBottomBar
                        .padding(12)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .swatchOutline(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var generatedBadge: some View {
        if isGenerated && !isSelecting, #available(iOS 26.0, *) {
            GeneratedBadge(diameter: isCompact ? 40 : 38)
        }
    }

    // MARK: - Normal layout: floating name (top) + hex/copy bar (bottom)

    private var namePill: some View {
        Text(colorName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlass(.regular, in: .capsule)
    }

    private var favoriteBadge: some View {
        ZStack {
            Image(systemName: "star.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
                .offset(y: -1)
        }
        .frame(width: 38, height: 38)
        .liquidGlass(.regular, in: .circle)
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

                if !isSelecting {
                    copyButton(diameter: 38)
                }
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
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .liquidGlass(.regular, in: .capsule)

                Spacer(minLength: 0)

                if !isSelecting {
                    copyButton(diameter: 40)
                }
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
