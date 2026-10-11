//
//  PaletteDraft.swift
//  Palettes
//
//  The palette being made or edited, before it's saved. New Palette and Edit
//  Palette both work on one of these; nothing reaches AppData until ✓.
//

import SwiftUI

struct PaletteDraft: Equatable {
    var name: String
    var colors: [PaletteColor]

    static let minimumColors = 2

    init(name: String = "", colors: [PaletteColor] = []) {
        self.name = name
        self.colors = colors
    }

    init(palette: PaletteViewModel) {
        self.init(name: palette.name, colors: palette.paletteColors)
    }

    var canSave: Bool { colors.count >= Self.minimumColors }

    var hexes: Set<String> { Set(colors.map { $0.hex.uppercased() }) }

    func contains(hex: String) -> Bool { hexes.contains(hex.uppercased()) }

    @discardableResult
    mutating func append(_ new: [PaletteColor]) -> Int {
        var seen = hexes
        var added = 0
        for color in new where !seen.contains(color.hex.uppercased()) {
            seen.insert(color.hex.uppercased())
            colors.append(color)
            added += 1
        }
        return added
    }

    mutating func replaceAll(with new: [PaletteColor]) {
        colors = []
        append(new)
    }

    @discardableResult
    mutating func remove(id: UUID) -> (index: Int, color: PaletteColor)? {
        guard let index = colors.firstIndex(where: { $0.id == id }) else { return nil }
        return (index, colors.remove(at: index))
    }

    /// Inserts a copy right after the original. A palette can't hold the same
    /// hex twice, so the copy's blue channel steps until it's unique.
    mutating func duplicate(id: UUID) {
        guard let index = colors.firstIndex(where: { $0.id == id }) else { return }
        let source = colors[index]
        let rgb = source.color.rgbComponents
        var b = Int(rgb.b.rounded())
        var hex = source.hex
        for step in 1...255 {
            b = (Int(rgb.b.rounded()) + step) % 256
            hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: Double(b))
            if !contains(hex: hex) { break }
        }
        let copy = PaletteColor(
            color: ColorAdjustment.color(r: rgb.r, g: rgb.g, b: Double(b)),
            hex: hex,
            name: source.name,
            role: nil
        )
        colors.insert(copy, at: index + 1)
    }

    mutating func move(id: UUID, to index: Int) {
        guard let from = colors.firstIndex(where: { $0.id == id }) else { return }
        let item = colors.remove(at: from)
        colors.insert(item, at: min(max(index, 0), colors.count))
    }

    mutating func setRole(_ role: String?, for id: UUID) {
        if let role {
            for i in colors.indices where colors[i].id != id
                && colors[i].role?.caseInsensitiveCompare(role) == .orderedSame {
                colors[i].role = nil
            }
        }
        if let i = colors.firstIndex(where: { $0.id == id }) { colors[i].role = role }
    }

    mutating func update(id: UUID, color: Color, hex: String, name: String) {
        guard let i = colors.firstIndex(where: { $0.id == id }) else { return }
        colors[i].color = color
        colors[i].hex = hex
        colors[i].name = name
    }

    func resolvedName(suggestion: String) -> String {
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return suggestion.isEmpty ? "Untitled Palette" : suggestion
    }

    func finalizedColors() -> [PaletteColor] {
        colors.map { entry in
            var entry = entry
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.name = trimmed.isEmpty ? ColorNamer.name(forHex: entry.hex) : trimmed
            return entry
        }
    }
}
