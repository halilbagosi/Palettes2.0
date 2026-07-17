//
//  GetColorHexIntent.swift
//  Palettes
//

import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct GetColorHexIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Color Hex"
    static let description = IntentDescription("Returns the hex code of a saved color.")

    @Parameter(title: "Color")
    var color: ColorEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the hex code of \(\.$color)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog & ShowsSnippetView {
        guard let stored = AppData.shared.colors.first(where: { $0.id == color.id }) else {
            throw PalettesIntentError.colorNotFound
        }
        return .result(
            value: stored.HEX,
            dialog: "\(stored.name) is \(stored.HEX).",
            view: ColorSnippetView(name: stored.name, hex: stored.HEX)
        )
    }
}
