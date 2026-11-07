//
//  LargeTitleCompat.swift
//  Palettes
//
//  The library tabs' title. iOS 26 and later: the plural ("Palettes") as a
//  system large title with the count as its subtitle ("12 palettes"). It was
//  a custom `.largeTitle` toolbar item with a count capsule, but the system
//  can't slide a custom title on push and pop: it faded in place over the
//  next screen's title. Earlier systems keep the plain string title with the
//  count in front ("12 Palettes").
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
                .navigationSubtitle(selecting == nil ? LibraryTitle.subtitle(noun, count: count) : "")
        } else {
            navigationTitle(selecting ?? LibraryTitle.text(noun, count: count))
        }
    }
}
