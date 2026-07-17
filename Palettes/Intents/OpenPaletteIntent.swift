//
//  OpenPaletteIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct OpenPaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Palette"
    static let description = IntentDescription("Opens a palette in Palettes.")
    static let openAppWhenRun = true

    @Parameter(title: "Palette")
    var palette: PaletteEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$palette)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard AppData.shared.palettes.contains(where: { $0.id == palette.id }) else {
            throw PalettesIntentError.paletteNotFound
        }
        AppData.shared.activeTab = .palettes
        AppData.shared.pendingOpenPaletteID = palette.id
        return .result()
    }
}
