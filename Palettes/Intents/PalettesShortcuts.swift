//
//  PalettesShortcuts.swift
//  Palettes
//
//  Siri phrases. Every phrase must contain \(.applicationName).
//

import AppIntents

@available(iOS 26.0, *)
struct PalettesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GeneratePaletteIntent(),
            phrases: [
                "Generate a palette in \(.applicationName)",
                "Make a palette with \(.applicationName)",
                "Create a color palette in \(.applicationName)"
            ],
            shortTitle: "Generate Palette",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: SaveColorIntent(),
            phrases: [
                "Save a color in \(.applicationName)",
                "Add a color to \(.applicationName)"
            ],
            shortTitle: "Save Color",
            systemImageName: "eyedropper"
        )
        AppShortcut(
            intent: OpenPaletteIntent(),
            phrases: [
                "Open \(\.$palette) in \(.applicationName)",
                "Show my \(\.$palette) palette in \(.applicationName)"
            ],
            shortTitle: "Open Palette",
            systemImageName: "swatchpalette"
        )
        AppShortcut(
            intent: GetColorHexIntent(),
            phrases: [
                "Get the hex of \(\.$color) in \(.applicationName)",
                "What's the hex code of \(\.$color) in \(.applicationName)"
            ],
            shortTitle: "Get Hex",
            systemImageName: "number"
        )
        AppShortcut(
            intent: FindPalettesIntent(),
            phrases: [
                "Find palettes in \(.applicationName)",
                "Search my palettes in \(.applicationName)"
            ],
            shortTitle: "Find Palettes",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: FindColorsIntent(),
            phrases: [
                "Find colors in \(.applicationName)",
                "Search my colors in \(.applicationName)"
            ],
            shortTitle: "Find Colors",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: SearchLibraryIntent(),
            phrases: [
                "Search \(.applicationName)"
            ],
            shortTitle: "Search Library",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: CreatePaletteIntent(),
            phrases: [
                "New empty palette in \(.applicationName)"
            ],
            shortTitle: "Create Palette",
            systemImageName: "plus.square.on.square"
        )
    }
}
