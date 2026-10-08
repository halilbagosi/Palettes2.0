//
//  GeneratePaletteIntent.swift
//  Palettes
//
//  Headless Siri/Shortcuts entry point into on-device palette generation.
//

import AppIntents
import FoundationModels
import SwiftUI

@available(iOS 26.0, *)
struct GeneratePaletteIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Palette"
    static let description = IntentDescription(
        "Generates a new color palette with Apple Intelligence and saves it to your library."
    )

    @Parameter(title: "Vibe", description: "The mood or theme, like 'warm sunset' or 'calm ocean'.")
    var vibe: String

    @Parameter(title: "Number of Colors", default: 6, controlStyle: .stepper, inclusiveRange: (2, 12))
    var size: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$vibe) palette with \(\.$size) colors")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog & ShowsSnippetView {
        guard case .available = SystemLanguageModel.default.availability else {
            throw PalettesIntentError.aiUnavailable
        }

        // Palettes come in even sizes (2–12), matching the in-app picker.
        let evenSize = min(12, max(2, size + size % 2))
        let generated = try await PaletteGenerator.generate(
            baseColors: [],
            size: evenSize,
            vibe: vibe,
            scheme: .auto,
            existingNames: AppData.shared.palettes.map { $0.name }
        )
        let saved = AppData.shared.addPalette(
            name: generated.name,
            paletteColors: generated.paletteColors,
            isGenerated: true
        )

        return .result(
            value: PaletteEntity(saved),
            dialog: "Saved '\(saved.name)' to your library.",
            view: PaletteSnippetView(name: saved.name, hexCodes: saved.hexCodes)
        )
    }
}
