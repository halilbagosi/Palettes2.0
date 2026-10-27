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
//  `-screenshotSeedSet vibrant` swaps in saturated palettes plus loose colors
//  spaced around the hue wheel, for marketing video.
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

    private static let vibrantPalettes: [(name: String, favorite: Bool, generated: Bool, swatches: [Swatch])] = [
        ("Neon Tokyo", true, true, [
            ("Hot Pink", "#FF2E88", "Primary"),
            ("Electric Cyan", "#00E5FF", "Accent"),
            ("Ultraviolet", "#7A00FF", "Secondary"),
            ("Signal Yellow", "#FFE600", "Highlight"),
            ("Laser Lime", "#B6FF00", "Surface"),
        ]),
        ("Sunset Pop", false, true, [
            ("Flamingo", "#FF5E8E", "Primary"),
            ("Blood Orange", "#FF6A00", "Accent"),
            ("Marigold", "#FFC21A", "Secondary"),
            ("Tangelo", "#FF8A3D", "Surface"),
            ("Fuchsia Pop", "#E81CFF", "Text"),
        ]),
        ("Tropic Punch", true, false, [
            ("Lagoon", "#00D4B4", "Primary"),
            ("Key Lime", "#A6E22E", "Accent"),
            ("Mango", "#FFB000", "Secondary"),
            ("Coral", "#FF5A5F", "Highlight"),
            ("Pool Blue", "#00A3FF", "Text"),
        ]),
        ("Berry Bliss", false, true, [
            ("Cherry", "#F0105F", "Primary"),
            ("Blueberry", "#3A5BFF", "Secondary"),
            ("Plum", "#9B2DFF", "Accent"),
            ("Lilac", "#C77DFF", "Surface"),
            ("Raspberry Pop", "#FF1F6B", "Text"),
        ]),
        ("Citrus Burst", false, false, [
            ("Lemon", "#FFF200", "Accent"),
            ("Lime Zest", "#7CFC00", "Secondary"),
            ("Navel", "#FF8C00", "Primary"),
            ("Grapefruit", "#FF4F5A", "Highlight"),
            ("Kiwi", "#3BE000", "Text"),
        ]),
        ("Ocean Glow", true, true, [
            ("Azure Wave", "#0096FF", "Primary"),
            ("Aqua Glow", "#00F5D4", "Accent"),
            ("Electric Blue", "#2E5BFF", "Secondary"),
            ("Seafoam", "#2BF5A0", "Surface"),
            ("Sky Flash", "#22D3FF", "Background"),
        ]),
        ("Candy Shop", false, true, [
            ("Bubblegum", "#FF5CE1", "Primary"),
            ("Spearmint", "#1FFFA8", "Accent"),
            ("Lemonade", "#FFEE33", "Highlight"),
            ("Sky Taffy", "#3DB8FF", "Secondary"),
            ("Grape Soda", "#A033FF", "Text"),
        ]),
        ("Aurora", true, true, [
            ("Green Flash", "#00FF87", "Accent"),
            ("Glacier Teal", "#00D1C1", "Primary"),
            ("Northern Violet", "#A64DFF", "Secondary"),
            ("Solar Magenta", "#F72585", "Highlight"),
            ("Borealis Blue", "#2F6BFF", "Background"),
        ]),
        ("Saffron Market", false, false, [
            ("Saffron Thread", "#FFA800", "Primary"),
            ("Chili", "#FF2D3D", "Accent"),
            ("Turmeric", "#FFC527", "Secondary"),
            ("Pistachio", "#5CE65C", "Highlight"),
            ("Paprika", "#FF5A1F", "Text"),
        ]),
        ("Midnight Neon", false, true, [
            ("Electric Violet", "#7B2FF7", "Primary"),
            ("Hot Magenta", "#F72585", "Accent"),
            ("Cyber Cyan", "#22D3FF", "Secondary"),
            ("Neon Orchid", "#D63BFF", "Background"),
            ("Volt", "#E6FF00", "Text"),
        ]),
    ]

    /// Loose colors every 12° of hue, so a hue sort reads as a rainbow.
    private static let vibrantLooseColors: [(name: String, hex: String)] = [
        ("Scarlet", "#F32929"), ("Vermilion", "#F35229"), ("Persimmon", "#F37A29"),
        ("Tangerine", "#F3A229"), ("Amber", "#F3CB29"), ("Canary", "#F3F329"),
        ("Sunflower", "#CBF329"), ("Citron", "#A2F329"), ("Chartreuse", "#7AF329"),
        ("Lime", "#52F329"), ("Spring Leaf", "#29F329"), ("Emerald", "#29F352"),
        ("Jade", "#29F37A"), ("Mint Glass", "#29F3A2"), ("Aqua", "#29F3CB"),
        ("Turquoise", "#29F3F3"), ("Cerulean", "#29CBF3"), ("Azure", "#29A2F3"),
        ("Sapphire", "#297AF3"), ("Cobalt", "#2952F3"), ("Ultramarine", "#2929F3"),
        ("Indigo", "#5229F3"), ("Iris", "#7A29F3"), ("Violet", "#A229F3"),
        ("Amethyst", "#CB29F3"), ("Orchid", "#F329F3"), ("Fuchsia", "#F329CB"),
        ("Magenta", "#F329A2"), ("Rose", "#F3297A"), ("Raspberry", "#F32952"),
    ]

    static func applyIfRequested(to appData: AppData) {
        guard isActive else { return }
        let defaults = UserDefaults.standard
        let vibrant = defaults.string(forKey: "screenshotSeedSet") == "vibrant"
        let palettes = vibrant ? Self.vibrantPalettes : Self.palettes

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
        if vibrant {
            for (index, loose) in vibrantLooseColors.enumerated() where seen.insert(loose.hex).inserted {
                colors.append(ColorViewModel(
                    name: loose.name,
                    color: Color(hex: loose.hex) ?? .gray,
                    HEX: loose.hex,
                    usedInPalette: false,
                    isFavorite: index % 7 == 0,
                    isGenerated: index % 2 == 0
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
