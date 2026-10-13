//
//  FindPalettesIntent.swift
//  Palettes
//

import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct FindPalettesIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Palettes"
    static let description = IntentDescription("Finds palettes in your library by name, tag, or color.")

    @Parameter(title: "Search Term", requestValueDialog: "What should I search for?")
    var searchTerm: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Find palettes matching \(\.$searchTerm)")
    }

    init() {}

    init(searchTerm: String?) {
        self.searchTerm = searchTerm
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[PaletteEntity]> & ProvidesDialog & ShowsSnippetView {
        await AppData.shared.waitUntilLoaded()
        let matches = LibrarySearch.palettes(matching: searchTerm, in: AppData.shared.palettes)
        let shown = Array(matches.prefix(3))
        return .result(
            value: matches.map(PaletteEntity.init),
            dialog: "Found \(matches.count) \(matches.count == 1 ? "palette" : "palettes")",
            view: VStack(spacing: 0) {
                ForEach(shown) { PaletteSnippetView(name: $0.name, hexCodes: $0.hexCodes) }
            }
        )
    }
}
