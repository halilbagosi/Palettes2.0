//
//  WidgetEntities.swift
//  PalettesWidgets
//
//  What the Edit Widget pickers list. Backed by the snapshot, iOS 17+.
//  (The app's PaletteEntity/ColorEntity are iOS 26-only and resolve
//  through the running app, so they can't be used here.)
//

import AppIntents
import Foundation

struct WidgetPaletteEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Palette"
    static let defaultQuery = WidgetPaletteQuery()

    let id: UUID
    let name: String

    init(_ palette: WidgetSnapshot.Palette) {
        id = palette.id
        name = palette.name
    }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct WidgetPaletteQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetPaletteEntity] {
        let snapshot = WidgetSnapshotStore.read()
        return identifiers.compactMap { snapshot.palette(id: $0) }.map(WidgetPaletteEntity.init)
    }

    /// Favorites first, then the rest, each in library order.
    func suggestedEntities() async throws -> [WidgetPaletteEntity] {
        let palettes = WidgetSnapshotStore.read().palettes
        return (palettes.filter(\.isFavorite) + palettes.filter { !$0.isFavorite }).map(WidgetPaletteEntity.init)
    }
}

struct WidgetColorEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Color"
    static let defaultQuery = WidgetColorQuery()

    let id: UUID
    let name: String
    let hex: String

    init(_ swatch: WidgetSnapshot.Swatch) {
        id = swatch.id
        name = swatch.name
        hex = swatch.hex
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(hex)")
    }
}

struct WidgetColorQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [WidgetColorEntity] {
        let snapshot = WidgetSnapshotStore.read()
        return identifiers.compactMap { snapshot.color(id: $0) }.map(WidgetColorEntity.init)
    }

    func suggestedEntities() async throws -> [WidgetColorEntity] {
        let colors = WidgetSnapshotStore.read().colors
        return (colors.filter(\.isFavorite) + colors.filter { !$0.isFavorite }).map(WidgetColorEntity.init)
    }
}

// MARK: - Favorites only

/// A palette for the Favorite Palettes widget's picker, which lists only
/// favorites. A palette unfavorited after it was picked no longer resolves,
/// so the widget never shows a palette that isn't a favorite.
struct FavoritePaletteEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Favorite Palette"
    static let defaultQuery = FavoritePaletteQuery()

    let id: UUID
    let name: String

    init(_ palette: WidgetSnapshot.Palette) {
        id = palette.id
        name = palette.name
    }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct FavoritePaletteQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [FavoritePaletteEntity] {
        let snapshot = WidgetSnapshotStore.read()
        return identifiers.compactMap { snapshot.palette(id: $0) }.filter(\.isFavorite).map(FavoritePaletteEntity.init)
    }

    func suggestedEntities() async throws -> [FavoritePaletteEntity] {
        WidgetSnapshotStore.read().palettes.filter(\.isFavorite).map(FavoritePaletteEntity.init)
    }
}

/// A color for the Favorite Colors widget's picker: favorites only, as above.
struct FavoriteColorEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Favorite Color"
    static let defaultQuery = FavoriteColorQuery()

    let id: UUID
    let name: String
    let hex: String

    init(_ swatch: WidgetSnapshot.Swatch) {
        id = swatch.id
        name = swatch.name
        hex = swatch.hex
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(hex)")
    }
}

struct FavoriteColorQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [FavoriteColorEntity] {
        let snapshot = WidgetSnapshotStore.read()
        return identifiers.compactMap { snapshot.color(id: $0) }.filter(\.isFavorite).map(FavoriteColorEntity.init)
    }

    func suggestedEntities() async throws -> [FavoriteColorEntity] {
        WidgetSnapshotStore.read().colors.filter(\.isFavorite).map(FavoriteColorEntity.init)
    }
}
