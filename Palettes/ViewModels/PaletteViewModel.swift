//
//  File.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import Foundation
import SwiftUI

struct PaletteColor: Identifiable, Sendable, Hashable {
    var id = UUID()
    var color: Color
    var hex: String
    var name: String
    var role: String? = nil
}

struct PaletteViewModel: Identifiable, Sendable, Hashable {
    var id = UUID()
    var name: String
    var paletteColors: [PaletteColor]
    var isFavorite: Bool = false

    var colors: [Color] { paletteColors.map { $0.color } }
    var hexCodes: [String] { paletteColors.map { $0.hex } }
    var colorNames: [String] { paletteColors.map { $0.name } }
    var colorRoles: [String] { paletteColors.map { $0.role ?? "" } }

    /// Zips the legacy parallel arrays into `paletteColors` by index.
    /// Missing hex/name entries (e.g. truncated CloudKit records) are padded
    /// by deriving them from the Color, so lengths can never desync. Missing
    /// or empty role entries map to `nil` (untagged).
    init(
        id: UUID = UUID(),
        name: String,
        colors: [Color],
        hexCodes: [String] = [],
        colorNames: [String] = [],
        colorRoles: [String] = [],
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.isFavorite = isFavorite
        self.paletteColors = colors.enumerated().map { index, color in
            let hex = index < hexCodes.count ? hexCodes[index] : ColorAdjustment.hexString(from: color)
            let name = index < colorNames.count ? colorNames[index] : ColorNamer.name(forHex: hex)
            let roleRaw = index < colorRoles.count ? colorRoles[index] : ""
            return PaletteColor(color: color, hex: hex, name: name, role: roleRaw.isEmpty ? nil : roleRaw)
        }
    }

    init(id: UUID = UUID(), name: String, paletteColors: [PaletteColor], isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.paletteColors = paletteColors
        self.isFavorite = isFavorite
    }

    static func == (lhs: PaletteViewModel, rhs: PaletteViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
