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

    @Parameter(
        title: "Vibe",
        description: "The mood or theme, like 'warm sunset' or 'calm ocean'.",
        requestValueDialog: "What vibe should the palette have?"
    )
    var vibe: String

    @Parameter(title: "Number of Colors", description: "Leave empty to let the app choose.", controlStyle: .stepper, inclusiveRange: (2, 12))
    var size: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Generate a \(\.$vibe) palette") {
            \.$size
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PaletteEntity> & ProvidesDialog & ShowsSnippetView {
        await AppData.shared.waitUntilLoaded()

        // The simulator has no Apple Intelligence; PaletteGenerator uses its
        // local fallback there, so skip the guard (same as GenerateView).
        #if !targetEnvironment(simulator)
        if let error = PalettesIntentError.error(for: SystemLanguageModel.default.availability) {
            throw error
        }
        #endif

        // Palettes come in even sizes (2–12), matching the in-app picker.
        let evenSize = size.map { min(12, max(2, $0 + $0 % 2)) }
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
