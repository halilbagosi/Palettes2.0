//
//  File.swift
//  Palettes
//
//  Created by Halil Bagosi on 18.2.26.
//
import Foundation
import SwiftUI

struct ColorViewModel: Identifiable, Sendable, Hashable {
    var id = UUID()
    var name: String { didSet { name = NameLimit.display(name) } }
    var color: Color
    var HEX: String
    var usedInPalette: Bool
    var isFavorite: Bool = false
    var isGenerated: Bool = false
    /// The generated palette this color was saved from, if any.
    var sourcePalette: GenerationSource? = nil

    init(
        id: UUID = UUID(),
        name: String,
        color: Color,
        HEX: String,
        usedInPalette: Bool,
        isFavorite: Bool = false,
        isGenerated: Bool = false,
        sourcePalette: GenerationSource? = nil
    ) {
        self.id = id
        self.name = NameLimit.display(name)
        self.color = color
        self.HEX = HEX
        self.usedInPalette = usedInPalette
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
        self.sourcePalette = sourcePalette
    }

    static func == (lhs: ColorViewModel, rhs: ColorViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// The generated palette a color was saved from: its id, to show its current
/// name, and its name at the time, for when it has since been deleted.
struct GenerationSource: Sendable, Hashable {
    var paletteID: UUID
    var paletteName: String
}
