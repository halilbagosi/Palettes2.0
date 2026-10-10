//
//  ToolbarCompat.swift
//  Palettes
//
//  iOS 27 toolbar APIs used for iPhone Duo's vertical bars. Built with the
//  iOS 27 SDK (Xcode 27, Swift 6.4) and running on iOS 27, a view's "more
//  actions" go into the system overflow menu (`ToolbarOverflowMenu`), as the
//  HIG asks: one overflow menu per bar, which the system also fills with the
//  items that no longer fit when bars move to the side. Older SDKs and
//  systems keep the app's own ellipsis menu.
//

import SwiftUI

extension View {
    /// Adds `content` as the view's overflow ("more") actions.
    @ViewBuilder
    func overflowMenu<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let items = content()
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            toolbar {
                ToolbarOverflowMenu { items }
            }
        } else {
            toolbar { LegacyOverflowMenu(items: items) }
        }
        #else
        toolbar { LegacyOverflowMenu(items: items) }
        #endif
    }
}

/// The ellipsis menu used before the system overflow menu existed.
private struct LegacyOverflowMenu<Items: View>: ToolbarContent {
    let items: Items

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                items
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }
}
