//
//  PaletteFace.swift
//  PalettesWidgets
//
//  A palette as full-height vertical bands, name bottom-left, copy
//  bottom-right. Used by the Palette and Palette of the Day widgets.
//

import SwiftUI

struct PaletteFace: View {
    let palette: WidgetSnapshot.Palette
    var caption: String? = nil

    private var firstLight: Bool { HexRGB.isLight(palette.hexCodes.first ?? HexRGB.fallbackGrey) }
    private var lastLight: Bool { HexRGB.isLight(palette.hexCodes.last ?? HexRGB.fallbackGrey) }

    var body: some View {
        ZStack {
            SwatchStrip(hexes: palette.hexCodes)
            VStack(alignment: .leading) {
                if let caption {
                    WidgetCaption(text: caption, onLight: firstLight)
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    NameCapsule(text: palette.name, onLight: firstLight)
                    Spacer(minLength: 8)
                    CopyButton(link: .copyPalette(palette.id), onLight: lastLight)
                }
            }
            .padding(14)
        }
    }
}
