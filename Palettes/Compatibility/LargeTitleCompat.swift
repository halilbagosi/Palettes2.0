//
//  LargeTitleCompat.swift
//  Palettes
//
//  The library tabs' large title. iOS 26 and later: the plural ("Palettes")
//  with the count in a capsule beside it, through the `.largeTitle` toolbar
//  placement; scrolled up, the inline title is the plural alone. Earlier
//  systems keep the plain string title with the count in front ("12 Palettes").
//

import SwiftUI

extension View {
    /// The library title for `count` items of `noun` ("Palette"), or
    /// "N Selected" while selecting.
    /// The branch is on the OS only, so entering or leaving selection never
    /// swaps the view (and its scroll position) out.
    @ViewBuilder
    func libraryTitle(_ noun: String, count: Int, selectedCount: Int?) -> some View {
        let selecting = selectedCount.map { "\($0) Selected" }
        if #available(iOS 26.0, *) {
            navigationTitle(selecting ?? LibraryTitle.plural(noun))
                .toolbar {
                    if selecting == nil {
                        ToolbarItem(placement: .largeTitle) {
                            LibraryLargeTitle(noun: noun, count: count)
                        }
                    }
                }
        } else {
            navigationTitle(selecting ?? LibraryTitle.text(noun, count: count))
        }
    }
}

/// "Palettes (12)": the title with its count in a capsule. The number sits
/// on the title's baseline with digits almost as tall as its capitals; the
/// capsule grows around the number as far as it needs to.
private struct LibraryLargeTitle: View {
    let noun: String
    let count: Int

    /// Re-reads the font sizes when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The count's font: digits are cap height, so 88% of the title's size
    /// gives digits just under the height of its capitals.
    private var countSize: CGFloat {
        (UIFont.preferredFont(forTextStyle: .largeTitle).pointSize * 0.88).rounded()
    }

    var body: some View {
        let font = UIFont.systemFont(ofSize: countSize, weight: .semibold)
        let inset = (font.capHeight * 0.4).rounded()
        let pillHeight = font.capHeight + inset * 2
        // The text frame runs ascender to descender; move the capsule from
        // that frame's center to the digits' center.
        let shift = (font.ascender + font.descender - font.capHeight) / 2

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(LibraryTitle.plural(noun))
                .font(.largeTitle.bold())
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: countSize, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, inset * 1.2)
                    .frame(minWidth: pillHeight)
                    .background {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: pillHeight)
                            .offset(y: shift)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LibraryTitle.text(noun, count: count))
        .accessibilityAddTraits(.isHeader)
    }
}
