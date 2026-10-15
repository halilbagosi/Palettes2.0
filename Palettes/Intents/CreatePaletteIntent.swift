//
//  CreatePaletteIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct CreatePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Palette"
    static let description = IntentDescription("Creates a new empty palette in your library.")

    @Parameter(title: "Name", requestValueDialog: "What should the palette be called?")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Create a palette named \(\.$name)")
    }

    /// Injected so tests never touch the real store; nil means `AppData.shared`,
    /// resolved on the main actor rather than in a nonisolated default value.
    private var injectedLibrary: AppData?
    @MainActor private var library: AppData { injectedLibrary ?? .shared }

    init() {}

    init(name: String, library: AppData? = nil) {
        self.name = name
        self.injectedLibrary = library
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog {
        let saved = library.addPalette(name: name, paletteColors: [])
        return .result(
            value: PaletteEntity(saved),
            dialog: "Created '\(saved.name)'."
        )
    }
}
