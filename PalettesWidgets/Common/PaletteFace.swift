//
//  PaletteFace.swift
//  PalettesWidgets
//
//  A palette as full-height vertical bands with its name bottom-left. Used
//  by the Palette and Palette of the Day widgets.
//

import SwiftUI

struct PaletteFace: View {
    let palette: WidgetSnapshot.Palette
    var caption: String? = nil

    private var firstLight: Bool { HexRGB.isLight(palette.hexCodes.first ?? HexRGB.fallbackGrey) }

    var body: some View {
        ZStack {
            SwatchStrip(hexes: palette.hexCodes)
            VStack(alignment: .leading) {
                if let caption {
                    WidgetCaption(text: caption, onLight: firstLight)
                }
                Spacer(minLength: 0)
                NameCapsule(text: palette.name, onLight: firstLight)
            }
            .padding(14)
        }
    }
}
