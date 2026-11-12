//
//  WidgetSample.swift
//  PalettesWidgets
//
//  What the widget gallery and placeholders draw.
//

import Foundation

enum WidgetSample {
    static let palette = WidgetSnapshot.Palette(
        id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000001")!,
        name: "Harbor",
        hexCodes: ["#0B3C5D", "#1A73A8", "#7FC8F8", "#F2E8CF", "#E2683C"],
        colorNames: ["Midnight Harbor", "Harbor Blue", "Sky", "Sand", "Ember"],
        isFavorite: true
    )

    static let color = WidgetSnapshot.Swatch(
        id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000002")!,
        name: "Harbor Blue",
        hex: "#1A73A8",
        isFavorite: true
    )

    static let snapshot = WidgetSnapshot(
        palettes: [
            palette,
            .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000003")!, name: "Orchard",
                  hexCodes: ["#3E8E5E", "#A7C957", "#F2E8CF", "#D9B44A", "#BC4749"],
                  colorNames: ["Leaf", "Pear", "Cream", "Honey", "Brick"], isFavorite: true),
            .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000004")!, name: "Dusk",
                  hexCodes: ["#2B1B3D", "#5C3C7A", "#C06C84", "#F67280", "#F8B195"],
                  colorNames: ["Night", "Plum", "Mauve", "Coral", "Peach"], isFavorite: true),
        ],
        colors: [color]
    )

    static let favoriteColors: [WidgetSnapshot.Swatch] = [
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000010")!, name: "Harbor Blue", hex: "#1A73A8", isFavorite: true),
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000011")!, name: "Sea Glass", hex: "#7FC8F8", isFavorite: true),
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000012")!, name: "Sand", hex: "#F2E8CF", isFavorite: true),
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000013")!, name: "Ember", hex: "#E2683C", isFavorite: true),
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000014")!, name: "Moss", hex: "#3E8E5E", isFavorite: true),
        .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000015")!, name: "Plum", hex: "#5C3C7A", isFavorite: true),
    ]

    static let favoriteColorsSnapshot = WidgetSnapshot(colors: favoriteColors)
}
