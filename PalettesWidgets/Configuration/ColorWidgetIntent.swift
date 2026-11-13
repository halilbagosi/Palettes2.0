//
//  ColorWidgetIntent.swift
//  PalettesWidgets
//

import AppIntents
import WidgetKit

enum ColorWidgetMode: String, AppEnum {
    case rotate, specific

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [ColorWidgetMode: DisplayRepresentation] = [
        .rotate: "Rotate Favorites",
        .specific: "Specific Color",
    ]
}

struct ColorWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Color"
    static let description = IntentDescription("Keep one color in view, or rotate through your favorites every hour.")

    @Parameter(title: "Show", default: .rotate)
    var mode: ColorWidgetMode

    /// Specific mode, unset: the first favorite color, else the first color.
    @Parameter(title: "Color")
    var color: WidgetColorEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, ColorWidgetMode.specific) {
            Summary {
                \.$mode
                \.$color
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }
}
