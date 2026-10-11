//
//  FindPalettesIntent.swift
//  Palettes
//

import AppIntents

@available(iOS 26.0, *)
struct FindPalettesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Palettes"
    static let description = IntentDescription("Finds palettes in your library, optionally filtered by name.")

    @Parameter(title: "Search Term")
    var searchTerm: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Find palettes matching \(\.$searchTerm)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PaletteEntity]> {
        let all = AppData.shared.palettes
        let matches: [PaletteViewModel]
        if let term = searchTerm?.trimmingCharacters(in: .whitespacesAndNewlines), !term.isEmpty {
            matches = all.filter { $0.name.localizedCaseInsensitiveContains(term) }
        } else {
            matches = all
        }
        return .result(value: matches.map(PaletteEntity.init))
    }
}
