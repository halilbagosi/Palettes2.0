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

    /// Injected so tests never touch the real store; nil means `AppData.shared`,
    /// resolved on the main actor rather than in a nonisolated default value.
    private var injectedLibrary: AppData?
    @MainActor private var library: AppData { injectedLibrary ?? .shared }

    init() {}

    init(searchTerm: String?, library: AppData? = nil) {
        self.searchTerm = searchTerm
        self.injectedLibrary = library
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[ColorEntity]> & ProvidesDialog & ShowsSnippetView {
        await library.waitUntilLoaded()
        let matches = LibrarySearch.colors(matching: searchTerm, in: library.colors)
        let shown = Array(matches.prefix(4))
        let term = LibrarySearch.normalize(searchTerm).query
        let dialog: IntentDialog = matches.isEmpty
            ? (term.isEmpty ? "No colors yet" : "No colors match '\(term)'")
            : "Found \(matches.count) \(matches.count == 1 ? "color" : "colors")"
        return .result(
            value: matches.map(ColorEntity.init),
            dialog: dialog,
            view: VStack(spacing: 0) {
                ForEach(shown) { ColorSnippetView(name: $0.name, hex: $0.HEX) }
            }
        )
    }
}
