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
    var name: String { didSet { name = NameLimit.display(name) } }
    var role: String? = nil

    init(id: UUID = UUID(), color: Color, hex: String, name: String, role: String? = nil) {
        self.id = id
        self.color = color
        self.hex = hex
        self.name = NameLimit.display(name)
        self.role = role
    }
}

struct PaletteViewModel: Identifiable, Sendable, Hashable {
    var id = UUID()
    var name: String { didSet { name = NameLimit.display(name) } }
    var paletteColors: [PaletteColor]
    var isFavorite: Bool = false
    var isGenerated: Bool = false
    /// The mode a generated palette used, as its menu named it ("Pastel").
    var generationMode: String? = nil
    /// The vibe a generated palette was described with.
    var generationVibe: String? = nil

    /// How the palette was generated, for its detail page: the vibe when
    /// it had one, else the mode. Nil when that isn't known.
    var generationNote: String? {
        guard isGenerated else { return nil }
        if let vibe = generationVibe, !vibe.isEmpty { return "Generated from “\(vibe)” vibe" }
        if let mode = generationMode, !mode.isEmpty { return "Generated using “\(mode)” mode" }
        return nil
    }

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
        isFavorite: Bool = false,
        isGenerated: Bool = false,
        generationMode: String? = nil,
        generationVibe: String? = nil
    ) {
        self.id = id
        self.name = NameLimit.display(name)
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
        self.generationMode = generationMode
        self.generationVibe = generationVibe
        self.paletteColors = colors.enumerated().map { index, color in
            let hex = index < hexCodes.count ? hexCodes[index] : ColorAdjustment.hexString(from: color)
            let name = index < colorNames.count ? colorNames[index] : ColorNamer.name(forHex: hex)
            let roleRaw = index < colorRoles.count ? colorRoles[index] : ""
            return PaletteColor(color: color, hex: hex, name: name, role: roleRaw.isEmpty ? nil : roleRaw)
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        paletteColors: [PaletteColor],
        isFavorite: Bool = false,
        isGenerated: Bool = false,
        generationMode: String? = nil,
        generationVibe: String? = nil
    ) {
        self.id = id
        self.name = NameLimit.display(name)
        self.paletteColors = paletteColors
        self.isFavorite = isFavorite
        self.isGenerated = isGenerated
        self.generationMode = generationMode
        self.generationVibe = generationVibe
    }

    static func == (lhs: PaletteViewModel, rhs: PaletteViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension PaletteViewModel {
    /// Plain-text form for drag and drop: the name, then one hex per line.
    var dragText: String {
        ([name] + hexCodes).joined(separator: "\n")
    }
}
