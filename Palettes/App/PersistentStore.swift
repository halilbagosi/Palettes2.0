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
    var isGenerated: Bool = false
    var sortIndex: Int = 0
    /// The generated palette this color was saved from (nil otherwise), and
    /// its name then, shown if that palette is later deleted.
    var sourcePaletteID: UUID? = nil
    var sourcePaletteName: String = ""

    init(
        id: UUID,
        name: String,
        hex: String,
        usedInPalette: Bool,
        isFavorite: Bool = false,
        isGenerated: Bool = false,
        sortIndex: Int,
        sourcePaletteID: UUID? = nil,
        sourcePaletteName: String = ""
    ) {
        self.id = id
        self.name = name
        self.hex = hex
        self.usedInPalette = usedInPalette
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
        self.sortIndex = sortIndex
        self.sourcePaletteID = sourcePaletteID
        self.sourcePaletteName = sourcePaletteName
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
    var isGenerated: Bool = false
    var sortIndex: Int = 0
    /// How a generated palette was made: the mode it used, and the vibe it
    /// was described with. Empty when unknown (made by hand, or saved before
    /// these were recorded).
    var generationMode: String = ""
    var generationVibe: String = ""

    init(
        id: UUID,
        name: String,
        hexCodes: [String],
        colorNames: [String],
        colorRoles: [String] = [],
        isFavorite: Bool = false,
        isGenerated: Bool = false,
        sortIndex: Int,
        generationMode: String = "",
        generationVibe: String = ""
    ) {
        self.id = id
        self.name = name
        self.hexCodes = hexCodes
        self.colorNames = colorNames
        self.colorRoles = colorRoles
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
        self.sortIndex = sortIndex
        self.generationMode = generationMode
        self.generationVibe = generationVibe
    }
}

/// A user-defined tag available app-wide for tagging palette colors, in
/// addition to `ColorRole.defaults`. Ordering is preserved via `sortIndex`;
/// uniqueness (case-insensitive, and against the built-in defaults) is
/// enforced by `AppData`, not the schema.
@Model
final class StoredTag {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0

    init(id: UUID, name: String, sortIndex: Int) {
        self.id = id
        self.name = name
        self.sortIndex = sortIndex
    }
}
