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
    var name: String { didSet { name = NameLimit.clamp(name) } }
    var color: Color
    var HEX: String
    var usedInPalette: Bool
    var isFavorite: Bool = false
    var isGenerated: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        color: Color,
        HEX: String,
        usedInPalette: Bool,
        isFavorite: Bool = false,
        isGenerated: Bool = false
    ) {
        self.id = id
        self.name = NameLimit.clamp(name)
        self.color = color
        self.HEX = HEX
        self.usedInPalette = usedInPalette
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
    }

    static func == (lhs: ColorViewModel, rhs: ColorViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
