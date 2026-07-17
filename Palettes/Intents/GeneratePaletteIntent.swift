//
//  GeneratePaletteIntent.swift
//  Palettes
//
//  Headless Siri/Shortcuts entry point into on-device palette generation.
//

import AppIntents
import FoundationModels

@available(iOS 26.0, *)
struct GeneratePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Palette"
    static let description = IntentDescription(
        "Generates a new color palette with Apple Intelligence and saves it to your library."
    )

    @Parameter(title: "Vibe", description: "The mood or theme, like 'warm sunset' or 'calm ocean'.")
    var vibe: String

    @Parameter(title: "Number of Colors", default: 5, controlStyle: .stepper, inclusiveRange: (2, 10))
    var size: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$vibe) palette with \(\.$size) colors")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog & ShowsSnippetView {
        guard case .available = SystemLanguageModel.default.availability else {
            throw PalettesIntentError.aiUnavailable
        }

        let generated = try await PaletteGenerator.generate(
            baseColors: [],
            size: min(max(size, 2), 10),
            vibe: vibe
        )
        let saved = AppData.shared.addPalette(name: generated.name, paletteColors: generated.paletteColors)

        return .result(
            value: PaletteEntity(saved),
            dialog: "Saved '\(saved.name)' to your library.",
            view: PaletteSnippetView(name: saved.name, hexCodes: saved.hexCodes)
        )
    }
}
