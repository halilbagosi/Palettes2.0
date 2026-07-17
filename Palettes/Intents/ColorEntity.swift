//
//  ColorEntity.swift
//  Palettes
//
//  App Intents representation of a saved color.
//

import AppIntents
import Foundation

@available(iOS 26.0, *)
struct ColorEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Color")
    static let defaultQuery = ColorEntityQuery()

    let id: UUID

    @Property(title: "Name")
    var name: String

    @Property(title: "Hex Code")
    var hex: String

    init(id: UUID, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }

    @MainActor
    init(_ color: ColorViewModel) {
        self.init(id: color.id, name: color.name, hex: color.HEX)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(hex)",
            image: .init(systemName: "circle.fill")
        )
    }
}

@available(iOS 26.0, *)
struct ColorEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ColorEntity] {
        AppData.shared.colors
            .filter { identifiers.contains($0.id) }
            .map(ColorEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ColorEntity] {
        AppData.shared.colors
            .filter {
                $0.name.localizedCaseInsensitiveContains(string)
                    || $0.HEX.localizedCaseInsensitiveContains(string)
            }
            .map(ColorEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ColorEntity] {
        AppData.shared.colors.prefix(10).map(ColorEntity.init)
    }
}
