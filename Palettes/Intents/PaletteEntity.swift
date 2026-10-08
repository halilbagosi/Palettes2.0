//
//  PaletteEntity.swift
//  Palettes
//
//  App Intents representation of a saved palette, resolvable by Siri,
//  Shortcuts, and Spotlight.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct PaletteEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Palette")
    static let defaultQuery = PaletteEntityQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Colors")
    var hexCodes: [String]

    init(id: UUID, name: String, hexCodes: [String]) {
        self.id = id
        self.name = name
        self.hexCodes = hexCodes
    }

    @MainActor
    init(_ palette: PaletteViewModel) {
        self.init(id: palette.id, name: palette.name, hexCodes: palette.hexCodes)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hexCodes.count) colors",
            image: .init(systemName: "swatchpalette.fill")
        )
    }
}

@available(iOS 26.0, *)
struct PaletteEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PaletteEntity] {
        AppData.shared.palettes
            .filter { identifiers.contains($0.id) }
            .map(PaletteEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PaletteEntity] {
        AppData.shared.palettes
            .filter { $0.name.localizedCaseInsensitiveContains(string) }
            .map(PaletteEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PaletteEntity] {
        AppData.shared.palettes.prefix(10).map(PaletteEntity.init)
    }
}
