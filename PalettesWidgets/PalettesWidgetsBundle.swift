//
//  PalettesWidgetsBundle.swift
//  PalettesWidgets
//

import SwiftUI
import WidgetKit

@main
struct PalettesWidgetsBundle: WidgetBundle {
    var body: some Widget {
        FavoritePalettesWidget()
        PaletteWidget()
        ColorWidget()
        ColorOfTheDayWidget()
        PaletteOfTheDayWidget()
        QuickCreateWidget()
        if #available(iOS 18.0, *) {
            NewColorControl()
            NewPaletteControl()
            ScanColorControl()
            ScanPaletteControl()
        }
    }
}
