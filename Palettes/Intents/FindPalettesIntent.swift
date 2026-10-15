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
    func perform() async throws -> some IntentResult & ReturnsValue<[PaletteEntity]> & ProvidesDialog & ShowsSnippetView {
        await library.waitUntilLoaded()
        let matches = LibrarySearch.palettes(matching: searchTerm, in: library.palettes)
        let shown = Array(matches.prefix(3))
        let term = LibrarySearch.normalize(searchTerm).query
        let dialog: IntentDialog = matches.isEmpty
            ? (term.isEmpty ? "No palettes yet" : "No palettes match '\(term)'")
            : "Found \(matches.count) \(matches.count == 1 ? "palette" : "palettes")"
        return .result(
            value: matches.map(PaletteEntity.init),
            dialog: dialog,
            view: VStack(spacing: 0) {
                ForEach(shown) { PaletteSnippetView(name: $0.name, hexCodes: $0.hexCodes) }
            }
        )
    }
}
