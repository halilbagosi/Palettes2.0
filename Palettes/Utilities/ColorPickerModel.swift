//
//  ColorPickerModel.swift
//  Palettes
//
//  The numbers behind the color picker: the swatch grid, the vivid colors a
//  new color starts on, and the harmony previews for "From One Color".
//

import SwiftUI

enum ColorPickerModel {
    static let gridColumns = 12
    static let gridRows = 8

    /// Hue columns × lightness rows, lightest first; the last row is grays.
    static func gridHexes() -> [[String]] {
        let brightness: [Double] = [1.0, 1.0, 1.0, 0.92, 0.75, 0.58, 0.4]
        let saturation: [Double] = [0.25, 0.5, 0.8, 1.0, 1.0, 1.0, 1.0]
        var rows: [[String]] = []
        for r in 0..<(gridRows - 1) {
            rows.append((0..<gridColumns).map { c in
                hex(Color(hue: Double(c) / Double(gridColumns), saturation: saturation[r], brightness: brightness[r]))
            })
        }
        rows.append((0..<gridColumns).map { c in
            let v = 1 - Double(c) / Double(gridColumns - 1)
            return hex(Color(white: v))
        })
        return rows
    }

    static let vividStarters: [String] = [
        "#FF5D00", "#FF2D55", "#FF9F0A", "#FFD60A", "#34C759", "#00C7BE",
        "#30B0C7", "#0A84FF", "#5E5CE6", "#BF5AF2", "#FF375F", "#AC8E68",
        "#E4572E", "#17BEBB", "#7A28CB", "#F2A541",
    ]

    static func randomStarter<G: RandomNumberGenerator>(using rng: inout G) -> String {
        vividStarters[Int(rng.next() % UInt64(vividStarters.count))]
    }

    static func randomStarter() -> String {
        var rng = SystemRandomNumberGenerator()
        return randomStarter(using: &rng)
    }

    /// A starter that isn't in `excluded` (uppercased "#RRGGBB"), so the picker
    /// that just added a color moves on to one that can be added too. Falls
    /// back to any starter if every one is taken.
    static func nextStarter<G: RandomNumberGenerator>(excluding excluded: Set<String>, using rng: inout G) -> String {
        let free = vividStarters.filter { !excluded.contains($0.uppercased()) }
        guard !free.isEmpty else { return randomStarter(using: &rng) }
        return free[Int(rng.next() % UInt64(free.count))]
    }

    static func nextStarter(excluding excluded: Set<String>) -> String {
        var rng = SystemRandomNumberGenerator()
        return nextStarter(excluding: excluded, using: &rng)
    }

    static let previewSchemes: [HarmonyScheme] = [.complementary, .splitComplementary, .analogous, .triadic, .monochromatic]

    /// One palette per scheme, each starting with `hex`. A fixed seed per
    /// base color keeps the previews still while nothing changes.
    static func harmonies(for hex: String, size: Int = 5) -> [(scheme: HarmonyScheme, hexes: [String])] {
        let normalized = PaletteBuilder.normalize([hex]).first ?? hex
        let seed = UInt64(normalized.dropFirst(), radix: 16) ?? 0
        return previewSchemes.map { scheme in
            let built = PaletteBuilder.build(PaletteBuildRequest(anchors: [normalized], size: size, scheme: scheme, seed: seed))
            return (scheme, built.hexes)
        }
    }

    /// Library colors are appended as they're saved, so the tail is newest.
    static func recentColors(_ library: [ColorViewModel], limit: Int = 12) -> [ColorViewModel] {
        Array(library.suffix(limit).reversed())
    }

    private static func hex(_ color: Color) -> String { ColorComposer.hexKey(color) }
}
