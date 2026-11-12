//
//  ColorWidgetIntent.swift
//  PalettesWidgets
//

import AppIntents
import WidgetKit

struct ColorWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Color"
    static let description = IntentDescription("Keep one color on your Home Screen.")

    /// Unset: the first favorite color, else the first color.
    @Parameter(title: "Color")
    var color: WidgetColorEntity?
}
