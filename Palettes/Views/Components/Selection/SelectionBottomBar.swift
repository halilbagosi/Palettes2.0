//
//  SelectionBottomBar.swift
//  Palettes
//
//  Bottom action bar shown while a library is in select mode. Rendered as
//  ToolbarContent so it drops into a view's `.toolbar { ... }` and appears once
//  the tab bar is hidden.
//

import SwiftUI

struct SelectionBottomBar: ToolbarContent {
    let count: Int
    /// Filled star = the first-selected item is already a favorite, so tapping
    /// will unfavorite; outline = tapping will favorite.
    var favoriteFilled: Bool = false
    let onDelete: () -> Void
    let onShare: () -> Void
    let onFavorite: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .tint(.red)
            .disabled(count == 0)

            Spacer()

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(count == 0)

            Spacer()

            Button(action: onFavorite) {
                Image(systemName: favoriteFilled ? "star.fill" : "star")
            }
            .disabled(count == 0)
        }
    }
}
