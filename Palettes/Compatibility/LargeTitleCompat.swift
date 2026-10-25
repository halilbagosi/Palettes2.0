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

/// "Palettes (12)": the title with its count in a capsule. The capsule
/// spans the full height of the title's letters: its bottom on the
/// baseline, its top level with the tallest letter (the "l" in "Palettes").
private struct LibraryLargeTitle: View {
    let noun: String
    let count: Int

    /// Re-reads the letter height when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Height of the title's tallest letter above the baseline, measured
    /// from the bold large-title glyphs themselves.
    private var letterHeight: CGFloat {
        let size = UIFont.preferredFont(forTextStyle: .largeTitle).pointSize
        let font = UIFont.systemFont(ofSize: size, weight: .bold) as CTFont
        let chars = Array(LibraryTitle.plural(noun).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
        let bounds = CTFontGetBoundingRectsForGlyphs(font, .default, glyphs, nil, glyphs.count)
        return bounds.maxY.rounded()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(LibraryTitle.plural(noun))
                .font(.largeTitle.bold())
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: letterHeight * 0.62, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, letterHeight * 0.3)
                    .frame(minWidth: letterHeight, minHeight: letterHeight, maxHeight: letterHeight)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
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
