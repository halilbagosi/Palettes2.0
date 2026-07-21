//
//  PersistentStore.swift
//  Palettes
//
//  SwiftData records mirroring the in-memory view models. AppData loads them
//  at launch and rewrites them (debounced) whenever the published arrays
//  change, so views keep working with plain value types. Models are
//  CloudKit-compatible: no unique constraints and every stored property has
//  an inline default. Uniqueness of `id` is enforced by AppData's upsert,
//  not the schema.
//

import Foundation
import SwiftData

@Model
final class StoredColor {
    var id: UUID = UUID()
    var name: String = ""
    var hex: String = ""
    var usedInPalette: Bool = false
    var isFavorite: Bool = false
    var sortIndex: Int = 0

    init(id: UUID, name: String, hex: String, usedInPalette: Bool, isFavorite: Bool = false, sortIndex: Int) {
        self.id = id
        self.name = name
        self.hex = hex
        self.usedInPalette = usedInPalette
        self.isFavorite = isFavorite
        self.sortIndex = sortIndex
    }
}

@Model
final class StoredPalette {
    var id: UUID = UUID()
    var name: String = ""
    var hexCodes: [String] = []
    var colorNames: [String] = []
    var colorRoles: [String] = []
    var isFavorite: Bool = false
    var sortIndex: Int = 0

    init(id: UUID, name: String, hexCodes: [String], colorNames: [String], colorRoles: [String] = [], isFavorite: Bool = false, sortIndex: Int) {
        self.id = id
        self.name = name
        self.hexCodes = hexCodes
        self.colorNames = colorNames
        self.colorRoles = colorRoles
        self.isFavorite = isFavorite
        self.sortIndex = sortIndex
    }
}
