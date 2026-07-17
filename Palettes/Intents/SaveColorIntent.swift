//
//  SaveColorIntent.swift
//  Palettes
//

import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct SaveColorIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Color"
    static let description = IntentDescription("Saves a hex color to your library.")

    @Parameter(title: "Hex Code", description: "A hex color like #4A90D9.")
    var hex: String

    @Parameter(title: "Name", description: "Leave empty to name it automatically.")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$hex) as \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ColorEntity> & ProvidesDialog & ShowsSnippetView {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        // Expand shorthand hex (#ABC / #ABCD) to full form, mirroring Color(hex:),
        // so stored HEX values are always 6 or 8 digits like the rest of the app.
        if cleaned.count == 3 || cleaned.count == 4 {
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        }
        let normalized = "#" + cleaned.uppercased()
        guard Color(hex: normalized) != nil else {
            throw PalettesIntentError.invalidHex(hex)
        }

        let resolvedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = (resolvedName?.isEmpty == false) ? resolvedName! : ColorNamer.name(forHex: normalized)
        let saved = AppData.shared.addColor(name: finalName, hex: normalized)

        return .result(
            value: ColorEntity(saved),
            dialog: "Saved '\(saved.name)' (\(saved.HEX)).",
            view: ColorSnippetView(name: saved.name, hex: saved.HEX)
        )
    }
}
