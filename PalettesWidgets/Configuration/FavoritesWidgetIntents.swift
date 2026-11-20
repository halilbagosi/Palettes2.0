//
//  FavoritesWidgetIntents.swift
//  PalettesWidgets
//
//  Edit Widget options for Favorite Palettes and Favorite Colors: show the
//  favorites (the default, as before) or a hand-picked list.
//

import AppIntents
import WidgetKit

enum FavoritesWidgetMode: String, AppEnum {
    case favorites, chosen

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [FavoritesWidgetMode: DisplayRepresentation] = [
        .favorites: "Favorites",
        .chosen: "Chosen",
    ]
}

struct FavoritePalettesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorite Palettes"
    static let description = IntentDescription("Show your favorite palettes, or pick which ones to show.")

    @Parameter(title: "Show", default: .favorites)
    var mode: FavoritesWidgetMode

    /// Chosen mode: in picked order, up to what the widget has room for.
    @Parameter(title: "Palettes", size: [.systemMedium: 3, .systemLarge: 5])
    var palettes: [WidgetPaletteEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, FavoritesWidgetMode.chosen) {
            Summary {
                \.$mode
                \.$palettes
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }
}

struct FavoriteColorsIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Favorite Colors"
    static let description = IntentDescription("Show your favorite colors, or pick which ones to show.")

    @Parameter(title: "Show", default: .favorites)
    var mode: FavoritesWidgetMode

    /// Chosen mode: in picked order, up to what the widget has room for.
    @Parameter(title: "Colors", size: [.systemSmall: 4, .systemMedium: 4, .systemLarge: 6])
    var colors: [WidgetColorEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, FavoritesWidgetMode.chosen) {
            Summary {
                \.$mode
                \.$colors
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }
}

/// Which items a favorites widget shows. Pure, so it can be reasoned about
/// (and tested) apart from WidgetKit.
enum FavoritesSelection {
    /// `chosenIDs` is only used in `.chosen` mode. Ids no longer in the
    /// snapshot are skipped; if none remain, the favorites are shown.
    static func palettes(
        mode: FavoritesWidgetMode, chosenIDs: [UUID], in snapshot: WidgetSnapshot, capacity: Int
    ) -> [WidgetSnapshot.Palette] {
        if mode == .chosen {
            let chosen = chosenIDs.compactMap { snapshot.palette(id: $0) }
            if !chosen.isEmpty { return Array(chosen.prefix(capacity)) }
        }
        return Array(snapshot.favoritePalettes.prefix(capacity))
    }

    static func colors(
        mode: FavoritesWidgetMode, chosenIDs: [UUID], in snapshot: WidgetSnapshot, capacity: Int
    ) -> [WidgetSnapshot.Swatch] {
        if mode == .chosen {
            let chosen = chosenIDs.compactMap { snapshot.color(id: $0) }
            if !chosen.isEmpty { return Array(chosen.prefix(capacity)) }
        }
        return Array(snapshot.favoriteColors.prefix(capacity))
    }
}
