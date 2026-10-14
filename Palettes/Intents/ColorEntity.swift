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
    /// Injected so tests never touch the real store; nil means `AppData.shared`,
    /// resolved on the main actor rather than in a nonisolated default value.
    private var injectedLibrary: AppData?
    @MainActor private var library: AppData { injectedLibrary ?? .shared }

    init() {}
    init(library: AppData) { self.injectedLibrary = library }

    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ColorEntity] {
        await library.waitUntilLoaded()
        return library.colors
            .filter { identifiers.contains($0.id) }
            .map(ColorEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [ColorEntity] {
        await library.waitUntilLoaded()
        return LibrarySearch.colors(matching: string, in: library.colors)
            .map(ColorEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [ColorEntity] {
        await library.waitUntilLoaded()
        return Self.suggested(from: library.colors)
    }

    /// Most recent 100, newest first, so shortcut phrases resolve for a real library.
    @MainActor
    static func suggested(from colors: [ColorViewModel]) -> [ColorEntity] {
        colors.suffix(100).reversed().map(ColorEntity.init)
    }
}
