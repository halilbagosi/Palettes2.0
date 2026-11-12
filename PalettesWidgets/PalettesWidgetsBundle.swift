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
        QuickCreateWidget()
        #if DEBUG
        CopySpikeWidget()
        #endif
    }
}
