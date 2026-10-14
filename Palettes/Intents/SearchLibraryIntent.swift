//
//  SearchLibraryIntent.swift
//  Palettes
//
//  "Search for ocean in Palettes": opens the Search tab with the term filled in.
//

import AppIntents

@available(iOS 26.0, *)
struct SearchLibraryIntent: AppIntent, ShowInAppSearchResultsIntent {
    static let title: LocalizedStringResource = "Search Library"
    static let description = IntentDescription("Opens Palettes search with your term.")
    static let searchScopes: [StringSearchScope] = [.general]
    static let openAppWhenRun = true

    @Parameter(title: "Search Term", requestValueDialog: "What should I search for?")
    var criteria: StringSearchCriteria

    init() {}

    init(criteria: StringSearchCriteria) {
        self.criteria = criteria
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppData.shared.pendingSearchTerm = criteria.term
        AppData.shared.activeTab = .search
        return .result()
    }
}
