//
//  CreatePaletteIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct CreatePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Palette"
    static let description = IntentDescription("Creates a new empty palette in your library.")

    @Parameter(title: "Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create a palette named \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog {
        let saved = AppData.shared.addPalette(name: name, paletteColors: [])
        return .result(
            value: PaletteEntity(saved),
            dialog: "Created '\(saved.name)'."
        )
    }
}
