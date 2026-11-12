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
        QuickCreateWidget()
        #if DEBUG
        CopySpikeWidget()
        #endif
    }
}
