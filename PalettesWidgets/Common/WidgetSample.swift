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
                  hexCodes: ["#3E8E5E", "#A7C957", "#F2E8CF", "#D9B44A", "#BC4749"], isFavorite: true),
            .init(id: UUID(uuidString: "6F1C2A4E-0000-4000-8000-000000000004")!, name: "Dusk",
                  hexCodes: ["#2B1B3D", "#5C3C7A", "#C06C84", "#F67280", "#F8B195"], isFavorite: true),
        ],
        colors: [color]
    )
}
