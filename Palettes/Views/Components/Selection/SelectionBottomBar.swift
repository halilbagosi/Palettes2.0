//
//  SelectionBottomBar.swift
//  Palettes
//
//  Bottom action bar shown while a library is in select mode. Rendered as
//  ToolbarContent so it drops into a view's `.toolbar { ... }` and appears once
//  the tab bar is hidden. Labels carry a title as well as a symbol so the
//  items can move into a vertical bar or the overflow menu (iPhone Duo).
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
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            .disabled(count == 0)
            .accessibilityLabel(count == 1 ? "Delete 1 item" : "Delete \(count) items")

            Spacer()

            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(count == 0)
            .accessibilityLabel(count == 1 ? "Share 1 item" : "Share \(count) items")

            Spacer()

            Button(action: onFavorite) {
                Label(favoriteFilled ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: favoriteFilled ? "star.fill" : "star")
            }
            .disabled(count == 0)
            .accessibilityLabel(favoriteFilled ? "Remove from Favorites" : "Add to Favorites")
        }
    }
}
