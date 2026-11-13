//
//  PaletteWidgetIntent.swift
//  PalettesWidgets
//

import AppIntents
import WidgetKit

enum PaletteWidgetMode: String, AppEnum {
    case rotate, specific

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static let caseDisplayRepresentations: [PaletteWidgetMode: DisplayRepresentation] = [
        .rotate: "Rotate Favorites",
        .specific: "Specific Palette",
    ]
}

struct PaletteWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Palette"
    static let description = IntentDescription("Show one palette, or rotate through your favorites every hour.")

    @Parameter(title: "Show", default: .rotate)
    var mode: PaletteWidgetMode

    @Parameter(title: "Palette")
    var palette: WidgetPaletteEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$mode, .equalTo, PaletteWidgetMode.specific) {
            Summary {
                \.$mode
                \.$palette
            }
        } otherwise: {
            Summary {
                \.$mode
            }
        }
    }
}
