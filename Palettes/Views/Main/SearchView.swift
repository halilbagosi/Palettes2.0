import SwiftUI

struct SearchView: View {

    enum SearchScope: String, CaseIterable {
        case all = "All"
        case colors = "Colors"
        case palettes = "Palettes"
    }

    @EnvironmentObject var appData: AppData
    @State private var searchText: String = ""
    @State private var scope: SearchScope = .all
    @State private var selectedHues: Set<HueCategory> = []
    @AppStorage("recentSearches") private var recentSearchesJSON: String = "[]"

    // MARK: - Query

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !query.isEmpty }

    /// Hex queries match with or without a leading "#".
    private var hexQuery: String {
        query.hasPrefix("#") ? String(query.dropFirst()) : query
    }

    private var libraryIsEmpty: Bool {
        appData.colors.isEmpty && appData.palettes.isEmpty
    }

    // MARK: - Search Matching

    var filteredColors: [ColorViewModel] {
        appData.colors.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            (!hexQuery.isEmpty && $0.HEX.localizedCaseInsensitiveContains(hexQuery))
        }
    }

    var filteredPalettes: [PaletteViewModel] {
        appData.palettes.filter { palette in
            palette.name.localizedCaseInsensitiveContains(query) ||
            palette.colorNames.contains(where: { $0.localizedCaseInsensitiveContains(query) }) ||
            (!hexQuery.isEmpty && palette.hexCodes.contains(where: { $0.localizedCaseInsensitiveContains(hexQuery) }))
        }
    }

    private var showColorResults: Bool { scope != .palettes && !filteredColors.isEmpty }
    private var showPaletteResults: Bool { scope != .colors && !filteredPalettes.isEmpty }
    private var hasResults: Bool { showColorResults || showPaletteResults }

    // MARK: - Browse (idle) Filtering

    private var browseColors: [ColorViewModel] {
        guard !selectedHues.isEmpty else { return appData.colors }
        return appData.colors.filter { selectedHues.contains($0.color.hueCategory) }
    }

    private var browsePalettes: [PaletteViewModel] {
        guard !selectedHues.isEmpty else { return appData.palettes }
        return appData.palettes.filter { palette in
            palette.colors.contains(where: { selectedHues.contains($0.hueCategory) })
        }
    }

    /// Only offer chips for hues that actually exist in the library.
    private var availableHues: [HueCategory] {
        let present = Set(appData.colors.map { $0.color.hueCategory })
            .union(appData.palettes.flatMap { $0.colors.map { $0.hueCategory } })
        return HueCategory.allCases.filter { present.contains($0) }
    }

    // MARK: - Recent Searches

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(recentSearchesJSON.utf8))) ?? []
    }

    private func recordRecentSearch() {
        guard !query.isEmpty else { return }
        var searches = recentSearches.filter { $0.caseInsensitiveCompare(query) != .orderedSame }
        searches.insert(query, at: 0)
        searches = Array(searches.prefix(5))
        if let data = try? JSONEncoder().encode(searches) {
            recentSearchesJSON = String(decoding: data, as: UTF8.self)
        }
    }

    private func clearRecentSearches() {
        recentSearchesJSON = "[]"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                if libraryIsEmpty {
                    SearchEmptyLibraryView {
                        appData.activeTab = .palettes
                    }
                } else if isSearching {
                    searchResults
                } else {
                    browseContent
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: ColorViewModel.self) { color in
                ColorDetailView(colorItem: color)
            }
            .navigationDestination(for: PaletteViewModel.self) { palette in
                PaletteDetailView(paletteName: palette.name, palette: palette)
            }
        }
        .searchable(text: $searchText, prompt: "Colors, palettes, hex…")
        .searchScopes($scope) {
            ForEach(SearchScope.allCases, id: \.self) { s in
                Text(s.rawValue).tag(s)
            }
        }
        .onSubmit(of: .search) {
            recordRecentSearch()
        }
        .sensoryFeedback(.selection, trigger: selectedHues)
        .sensoryFeedback(.selection, trigger: scope)
    }

    // MARK: - Active Search Results

    private var searchResults: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if showColorResults {
                SearchSectionHeader(title: "Colors", count: filteredColors.count)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 12)
                ], spacing: 12) {
                    ForEach(filteredColors) { color in
                        NavigationLink(value: color) {
                            ColorCellSearch(
                                colorName: color.name,
                                hexCode: color.HEX,
                                color: color.color,
                                highlight: query
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                        .simultaneousGesture(TapGesture().onEnded { recordRecentSearch() })
                    }
                }
            }

            if showPaletteResults {
                SearchSectionHeader(title: "Palettes", count: filteredPalettes.count)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 12)
                ], spacing: 10) {
                    ForEach(filteredPalettes) { palette in
                        NavigationLink(value: palette) {
                            PaletteCellSearch(
                                paletteName: palette.name,
                                colors: palette.colors,
                                highlight: query
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                        .simultaneousGesture(TapGesture().onEnded { recordRecentSearch() })
                    }
                }
            }

            if !hasResults {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 60)
            }
        }
        .padding()
        .animation(.spring(response: 0.3), value: scope)
    }

    // MARK: - Browse (Idle) Content

    private var browseContent: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if !recentSearches.isEmpty {
                RecentSearchesRow(
                    searches: recentSearches,
                    onSelect: { term in searchText = term },
                    onClear: clearRecentSearches
                )
            }

            hueChips

            if !browseColors.isEmpty {
                SearchSectionHeader(title: "Colors", count: browseColors.count)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 12)
                ], spacing: 12) {
                    ForEach(browseColors) { color in
                        NavigationLink(value: color) {
                            ColorCellSearch(
                                colorName: color.name,
                                hexCode: color.HEX,
                                color: color.color
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                    }
                }
            }

            if !browsePalettes.isEmpty {
                SearchSectionHeader(title: "Palettes", count: browsePalettes.count)

                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 12)
                ], spacing: 10) {
                    ForEach(browsePalettes) { palette in
                        NavigationLink(value: palette) {
                            PaletteCellSearch(
                                paletteName: palette.name,
                                colors: palette.colors
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                    }
                }
            }

            if browseColors.isEmpty && browsePalettes.isEmpty, !selectedHues.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "paintpalette",
                    description: Text("Nothing in your library falls in the selected hue range\(selectedHues.count == 1 ? "" : "s").")
                )
                .padding(.top, 40)
            }
        }
        .padding()
        .animation(.spring(response: 0.3), value: selectedHues)
    }

    private var hueChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HueChip(
                    title: "All",
                    swatch: nil,
                    isSelected: selectedHues.isEmpty
                ) {
                    withAnimation(.spring(response: 0.3)) { selectedHues.removeAll() }
                }

                ForEach(availableHues) { hue in
                    HueChip(
                        title: hue.rawValue,
                        swatch: hue.representativeColor,
                        isSelected: selectedHues.contains(hue)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            if selectedHues.contains(hue) {
                                selectedHues.remove(hue)
                            } else {
                                selectedHues.insert(hue)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

#Preview {
    SearchView()
        .environmentObject(AppData())
}
