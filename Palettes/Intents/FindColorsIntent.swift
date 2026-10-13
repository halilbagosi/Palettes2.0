//
//  FindColorsIntent.swift
//  Palettes
//

import AppIntents
import SwiftUI

@available(iOS 26.0, *)
struct FindColorsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Colors"
    static let description = IntentDescription("Finds colors in your library by name, hex code, or hue like blue or warm.")

    @Parameter(title: "Search Term", requestValueDialog: "What should I search for?")
    var searchTerm: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Find colors matching \(\.$searchTerm)")
    }

    init() {}

    init(searchTerm: String?) {
        self.searchTerm = searchTerm
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ColorEntity]> & ProvidesDialog & ShowsSnippetView {
        await AppData.shared.waitUntilLoaded()
        let matches = LibrarySearch.colors(matching: searchTerm, in: AppData.shared.colors)
        let shown = Array(matches.prefix(4))
        return .result(
            value: matches.map(ColorEntity.init),
            dialog: "Found \(matches.count) \(matches.count == 1 ? "color" : "colors")",
            view: VStack(spacing: 0) {
                ForEach(shown) { ColorSnippetView(name: $0.name, hex: $0.HEX) }
            }
        )
    }
}
