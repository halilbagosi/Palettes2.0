//
//  FavoritesSelection.swift
//  Palettes (app + widgets)
//
//  Which items a Favorite Palettes / Favorite Colors widget shows. Pure, so
//  it is testable apart from WidgetKit.
//

import Foundation

nonisolated enum FavoritesSelection {
    /// `chosenIDs` only counts when `useChosen` is true. Duplicates keep their
    /// first position, ids no longer in the snapshot are skipped, and when
    /// nothing remains the favorites are shown. At most `capacity` items.
    static func palettes(
        useChosen: Bool, chosenIDs: [UUID], in snapshot: WidgetSnapshot, capacity: Int
    ) -> [WidgetSnapshot.Palette] {
        if useChosen {
            let chosen = unique(chosenIDs).compactMap { snapshot.palette(id: $0) }
            if !chosen.isEmpty { return Array(chosen.prefix(capacity)) }
        }
        return Array(snapshot.favoritePalettes.prefix(capacity))
    }

    static func colors(
        useChosen: Bool, chosenIDs: [UUID], in snapshot: WidgetSnapshot, capacity: Int
    ) -> [WidgetSnapshot.Swatch] {
        if useChosen {
            let chosen = unique(chosenIDs).compactMap { snapshot.color(id: $0) }
            if !chosen.isEmpty { return Array(chosen.prefix(capacity)) }
        }
        return Array(snapshot.favoriteColors.prefix(capacity))
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
