//
//  ScreenshotSeed.swift
//  Palettes
//
//  DEBUG-only demo library for App Store screenshots. Launch with
//  `-screenshotSeed YES` to start on an in-memory store filled with the
//  palettes below, so a simulator's real library is never touched. Add
//  `-screenshotOpenPalette <index>` to push that palette's detail,
//  `-screenshotTab <palettes|colors|search|generate>` to start on a tab, and
//  `-screenshotSheet <export|edit>` to open that sheet on the open palette.
//

#if DEBUG
import SwiftUI

enum ScreenshotSeed {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "screenshotSeed") }

    private typealias Swatch = (name: String, hex: String, role: String?)

    private static let palettes: [(name: String, favorite: Bool, generated: Bool, swatches: [Swatch])] = [
        ("Kyoto Dusk", true, true, [
            ("Lantern Glow", "#F2A65A", "Accent"),
            ("Temple Red", "#C8553D", "Primary"),
            ("Plum Shadow", "#5B3758", "Secondary"),
            ("Indigo Night", "#2E2A4F", "Text"),
            ("Rice Paper", "#F6EFE6", "Background"),
        ]),
        ("Coastal Morning", false, true, [
            ("Sea Glass", "#9AD1D4", "Secondary"),
            ("Harbor Blue", "#2F6690", "Primary"),
            ("Sandbar", "#E9D8A6", "Surface"),
            ("Coral Buoy", "#EE6C4D", "Accent"),
            ("Deep Tide", "#1B3A4B", "Text"),
        ]),
        ("Sage & Clay", true, false, [
            ("Sage Leaf", "#A3B18A", "Primary"),
            ("Moss", "#588157", "Secondary"),
            ("Terracotta", "#C97B63", "Accent"),
            ("Linen", "#F1EBE1", "Background"),
            ("Bark", "#3A3A2E", "Text"),
        ]),
        ("Midnight Neon", false, true, [
            ("Electric Violet", "#7B2FF7", "Primary"),
            ("Hot Magenta", "#F72585", "Accent"),
            ("Cyber Cyan", "#4CC9F0", "Secondary"),
            ("Ink", "#10002B", "Background"),
            ("Haze", "#E0AAFF", "Text"),
        ]),
        ("Citrus Grove", false, false, [
            ("Lemon Zest", "#FFD23F", "Accent"),
            ("Tangerine", "#FF8C42", "Primary"),
            ("Lime Leaf", "#8AC926", "Success"),
            ("Pith", "#FFF8E7", "Background"),
            ("Olive Wood", "#4A4E2A", "Text"),
        ]),
        ("Nordic Fog", true, true, [
            ("Fjord", "#4A6C8C", "Primary"),
            ("Frost", "#DCE6EE", "Background"),
            ("Slate Stone", "#6B7A86", "Secondary"),
            ("Birch", "#F7F5F0", "Surface"),
            ("Pine Night", "#1F2A33", "Text"),
        ]),
        ("Desert Bloom", false, true, [
            ("Cactus Flower", "#E56B9F", "Accent"),
            ("Dune", "#E8C39E", "Background"),
            ("Canyon", "#B5543C", "Primary"),
            ("Agave", "#6A8D73", "Secondary"),
            ("Dusk Sky", "#46354F", "Text"),
        ]),
        ("Berry Market", false, false, [
            ("Blackberry", "#3D1F3A", "Text"),
            ("Raspberry", "#D7263D", "Primary"),
            ("Blueberry", "#4F6D9A", "Secondary"),
            ("Cream", "#FBF5EF", "Background"),
            ("Mint Sprig", "#7FC8A9", "Accent"),
        ]),
        ("Lavender Fields", true, true, [
            ("Lavender", "#B8A1E3", "Primary"),
            ("Wisteria", "#8E7CC3", "Secondary"),
            ("Butter", "#F9E79F", "Accent"),
            ("Morning Mist", "#F4F1FA", "Background"),
            ("Aubergine", "#3B2C4F", "Text"),
        ]),
        ("Tropic Lagoon", false, true, [
            ("Lagoon", "#00A6A6", "Primary"),
            ("Palm", "#2D6A4F", "Secondary"),
            ("Mango", "#FFB140", "Accent"),
            ("White Sand", "#FFF4E0", "Background"),
            ("Reef Night", "#0B3142", "Text"),
        ]),
        ("Autumn Orchard", false, false, [
            ("Crabapple", "#A63D40", "Primary"),
            ("Pear", "#C9B458", "Secondary"),
            ("Pumpkin", "#E9724C", "Accent"),
            ("Oat", "#F3E9D2", "Background"),
            ("Walnut", "#4E3524", "Text"),
        ]),
        ("Espresso Bar", true, false, [
            ("Crema", "#D4A373", "Accent"),
            ("Roast", "#6F4E37", "Primary"),
            ("Steamed Milk", "#FAEDCD", "Background"),
            ("Copper Pot", "#B5651D", "Secondary"),
            ("Dark Roast", "#2B1B17", "Text"),
        ]),
    ]

    static func applyIfRequested(to appData: AppData) {
        guard isActive else { return }
        let defaults = UserDefaults.standard

        let models = palettes.map { palette in
            PaletteViewModel(
                name: palette.name,
                paletteColors: palette.swatches.map {
                    PaletteColor(color: Color(hex: $0.hex) ?? .gray, hex: $0.hex, name: $0.name, role: $0.role)
                },
                isFavorite: palette.favorite,
                isGenerated: palette.generated
            )
        }
        // The library lists newest first; reversed so Kyoto Dusk leads.
        appData.palettes = models.reversed()

        var seen = Set<String>()
        var colors: [ColorViewModel] = []
        for (index, palette) in palettes.enumerated() {
            for swatch in palette.swatches where seen.insert(swatch.hex).inserted {
                colors.append(ColorViewModel(
                    name: swatch.name,
                    color: Color(hex: swatch.hex) ?? .gray,
                    HEX: swatch.hex,
                    usedInPalette: true,
                    isFavorite: index % 3 == 0 && swatch.role == "Accent",
                    isGenerated: palette.generated
                ))
            }
        }
        appData.colors = colors

        let tab = defaults.string(forKey: "screenshotTab").flatMap(TabValue.init(rawValue:))
        let openIndex = defaults.object(forKey: "screenshotOpenPalette") as? Int
            ?? defaults.string(forKey: "screenshotOpenPalette").flatMap(Int.init)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            if let tab { appData.activeTab = tab }
            if let openIndex, models.indices.contains(openIndex) {
                appData.pendingOpenPaletteID = models[openIndex].id
            }
        }
    }
}
#endif
