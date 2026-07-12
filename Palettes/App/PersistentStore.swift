//
//  PersistentStore.swift
//  Palettes
//
//  SwiftData records mirroring the in-memory view models. AppData loads them
//  at launch and rewrites them (debounced) whenever the published arrays
//  change, so views keep working with plain value types.
//

import Foundation
import SwiftData

@Model
final class StoredColor {
    @Attribute(.unique) var id: UUID
    var name: String
    var hex: String
    var usedInPalette: Bool
    var sortIndex: Int

    init(id: UUID, name: String, hex: String, usedInPalette: Bool, sortIndex: Int) {
        self.id = id
        self.name = name
        self.hex = hex
        self.usedInPalette = usedInPalette
        self.sortIndex = sortIndex
    }
}

@Model
final class StoredPalette {
    @Attribute(.unique) var id: UUID
    var name: String
    var hexCodes: [String]
    var colorNames: [String]
    var sortIndex: Int

    init(id: UUID, name: String, hexCodes: [String], colorNames: [String], sortIndex: Int) {
        self.id = id
        self.name = name
        self.hexCodes = hexCodes
        self.colorNames = colorNames
        self.sortIndex = sortIndex
    }
}
