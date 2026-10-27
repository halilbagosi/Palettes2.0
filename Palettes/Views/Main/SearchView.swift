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
    @State private var selectedTags: Set<String> = []
    @AppStorage(AppData.recentSearchesKey) private var recentSearchesJSON: String = "[]"

    /// Derived lists cached in state and refreshed only when their inputs change,
    /// so body runs while scrolling (or from unrelated `AppData` publishes) don't
    /// re-filter the library. Nil until the first refresh, when they're computed live.
    @State private var cachedIndex: SearchBrowseIndex?
    @State private var cachedBrowse: SearchLists?
    @State private var cachedResults: SearchLists?

    // MARK: - Query

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool { !query.isEmpty }

    private var libraryIsEmpty: Bool {
        appData.colors.isEmpty && appData.palettes.isEmpty
    }

    // MARK: - Search Matching

    var filteredColors: [ColorViewModel] {
        cachedResults?.colors ?? LibrarySearch.colors(matching: query, in: appData.colors)
    }

    var filteredPalettes: [PaletteViewModel] {
        cachedResults?.palettes ?? LibrarySearch.palettes(matching: query, in: appData.palettes)
    }

    private var showColorResults: Bool { scope != .palettes && !filteredColors.isEmpty }
    private var showPaletteResults: Bool { scope != .colors && !filteredPalettes.isEmpty }
    private var hasResults: Bool { showColorResults || showPaletteResults }

    private var browseResultIDs: [UUID] {
        browseColors.map(\.id) + browsePalettes.map(\.id)
    }

    // MARK: - Browse (idle) Filtering

    private var libraryIndex: SearchBrowseIndex {
        cachedIndex ?? SearchBrowseIndex(colors: appData.colors, palettes: appData.palettes)
    }

    private var browseColors: [ColorViewModel] {
        cachedBrowse?.colors ?? libraryIndex.colors(appData.colors, hues: selectedHues)
    }

    private var browsePalettes: [PaletteViewModel] {
        cachedBrowse?.palettes ?? libraryIndex.palettes(appData.palettes, hues: selectedHues, tags: selectedTags)
    }

    /// Only offer chips for hues that actually exist in the library.
    private var availableHues: [HueCategory] { libraryIndex.availableHues }

    /// Only offer chips for color-role tags that actually exist in the library's palettes.
    private var availableTags: [String] { libraryIndex.availableTags }

    // MARK: - Cache Refresh

    /// `onReceive` fires before `AppData` stores the new value, so the changed
    /// list arrives as an argument and the other is read from `appData`.
    private func refreshLibrary(colors: [ColorViewModel], palettes: [PaletteViewModel]) {
        let index = SearchBrowseIndex(colors: colors, palettes: palettes)
        cachedIndex = index
        cachedBrowse = SearchLists(
            colors: index.colors(colors, hues: selectedHues),
            palettes: index.palettes(palettes, hues: selectedHues, tags: selectedTags)
        )
        refreshResults(colors: colors, palettes: palettes)
    }

    private func refreshBrowse() {
        let index = libraryIndex
        cachedBrowse = SearchLists(
            colors: index.colors(appData.colors, hues: selectedHues),
            palettes: index.palettes(appData.palettes, hues: selectedHues, tags: selectedTags)
        )
    }

    private func refreshResults(colors: [ColorViewModel]? = nil, palettes: [PaletteViewModel]? = nil) {
        cachedResults = SearchLists(
            colors: LibrarySearch.colors(matching: query, in: colors ?? appData.colors),
            palettes: LibrarySearch.palettes(matching: query, in: palettes ?? appData.palettes)
        )
    }

    /// A Search intent (Siri/Shortcuts/Spotlight) asked for a term: show it, then clear.
    private func consumePendingSearchTerm() {
        guard let term = appData.takePendingSearchTerm() else { return }
        searchText = term
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SettingsToolbarButton()
                }
            }
            .featureIntro(.search)
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
        .onChange(of: appData.pendingSearchTerm, initial: true) { _, _ in consumePendingSearchTerm() }
        .onReceive(appData.$colors) { refreshLibrary(colors: $0, palettes: appData.palettes) }
        .onReceive(appData.$palettes) { refreshLibrary(colors: appData.colors, palettes: $0) }
        .onChange(of: selectedHues) { refreshBrowse() }
        .onChange(of: selectedTags) { refreshBrowse() }
        .onChange(of: query) { refreshResults() }
        .onSubmit(of: .search) {
            recordRecentSearch()
        }
        .sensoryFeedback(.selection, trigger: selectedHues)
        .sensoryFeedback(.selection, trigger: selectedTags)
        .sensoryFeedback(.selection, trigger: scope)
    }

    // MARK: - Active Search Results

    private var searchResults: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if showColorResults {
                SearchColorSection(colors: filteredColors, highlight: query, onOpen: recordRecentSearch)
                    .equatable()
            }

            if showPaletteResults {
                SearchPaletteSection(palettes: filteredPalettes, highlight: query, onOpen: recordRecentSearch)
                    .equatable()
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
            let recent = recentSearches
            if !recent.isEmpty {
                RecentSearchesRow(
                    searches: recent,
                    onSelect: { term in searchText = term },
                    onClear: clearRecentSearches
                )
            }

            hueChips

            browseResultSections
        }
        .padding()
    }

    private var browseResultSections: some View {
        VStack(alignment: .leading, spacing: 20) {

            if !browseColors.isEmpty {
                SearchColorSection(colors: browseColors)
                    .equatable()
            }

            if !availableTags.isEmpty {
                tagChips
            }

            if !browsePalettes.isEmpty {
                SearchPaletteSection(palettes: browsePalettes)
                    .equatable()
            }

            if browseColors.isEmpty && browsePalettes.isEmpty, (!selectedHues.isEmpty || !selectedTags.isEmpty) {
                PaletteEmptyView(
                    imageName: "paintpalette",
                    title: "No matches",
                    message: "Nothing in your library matches the selected filters.",
                    actionTitle: "Clear Filters",
                    actionImage: "xmark.circle",
                    compact: true
                ) {
                    selectedHues.removeAll()
                    selectedTags.removeAll()
                }
                .padding(.top, 40)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 1), value: browseResultIDs)
    }

    /// The content margin the chip rows scroll into, fading out across it
    /// instead of running under the screen's edge.
    private static var chipMargin: CGFloat { 16 }

    private var hueChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HueChip(
                    title: "All",
                    tint: nil,
                    isSelected: selectedHues.isEmpty
                ) {
                    selectedHues.removeAll()
                }

                ForEach(availableHues) { hue in
                    HueChip(
                        title: hue.rawValue,
                        tint: hue.representativeColor,
                        isSelected: selectedHues.contains(hue)
                    ) {
                        if selectedHues.contains(hue) {
                            selectedHues.remove(hue)
                        } else {
                            selectedHues.insert(hue)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, Self.chipMargin)
            .animation(.spring(response: 0.24, dampingFraction: 1), value: selectedHues)
        }
        .chipRowFade(margin: Self.chipMargin)
    }

    private var tagChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HueChip(
                    title: "All",
                    tint: nil,
                    isSelected: selectedTags.isEmpty
                ) {
                    selectedTags.removeAll()
                }

                ForEach(availableTags, id: \.self) { tag in
                    HueChip(
                        title: tag,
                        tint: nil,
                        isSelected: selectedTags.contains(tag)
                    ) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, Self.chipMargin)
            .animation(.spring(response: 0.24, dampingFraction: 1), value: selectedTags)
        }
        .chipRowFade(margin: Self.chipMargin)
    }
}

// MARK: - Result Sections

/// A pair of filtered lists, cached together by `SearchView`.
private struct SearchLists {
    var colors: [ColorViewModel]
    var palettes: [PaletteViewModel]
}

/// Header plus color grid, `Equatable` so `SearchView` body re-runs that leave
/// the list unchanged don't rebuild its cards. `onOpen` is ignored in `==`: it
/// only records the current query, which `highlight` already reflects.
private struct SearchColorSection: View, Equatable {
    let colors: [ColorViewModel]
    var highlight: String = ""
    /// Runs alongside navigation when a card is tapped.
    var onOpen: (() -> Void)? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.highlight == rhs.highlight && (lhs.onOpen == nil) == (rhs.onOpen == nil)
            && lhs.colors.count == rhs.colors.count
            && zip(lhs.colors, rhs.colors).allSatisfy { $0.hasSameSearchContent(as: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionHeader(title: "Colors", count: colors.count)

            FoldAwareGrid(minimum: 160, maximum: 280, spacing: 12, rowSpacing: 12) {
                ForEach(colors) { color in
                    NavigationLink(value: color) {
                        ColorCellSearch(
                            colorName: color.name,
                            hexCode: color.HEX,
                            color: color.color,
                            highlight: highlight,
                            isGenerated: color.isGenerated
                        )
                        .equatable()
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                    .simultaneousGesture(TapGesture().onEnded { onOpen?() }, including: onOpen == nil ? .none : .all)
                    .transition(.opacity)
                }
            }
        }
    }
}

/// Header plus palette grid; see `SearchColorSection`.
private struct SearchPaletteSection: View, Equatable {
    let palettes: [PaletteViewModel]
    var highlight: String = ""
    var onOpen: (() -> Void)? = nil

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.highlight == rhs.highlight && (lhs.onOpen == nil) == (rhs.onOpen == nil)
            && lhs.palettes.count == rhs.palettes.count
            && zip(lhs.palettes, rhs.palettes).allSatisfy { $0.hasSameSearchContent(as: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionHeader(title: "Palettes", count: palettes.count)

            FoldAwareGrid(minimum: 320, maximum: 560, spacing: 12, rowSpacing: 10) {
                ForEach(palettes) { palette in
                    NavigationLink(value: palette) {
                        PaletteCellSearch(
                            paletteName: palette.name,
                            colors: palette.colors,
                            highlight: highlight,
                            isGenerated: palette.isGenerated
                        )
                        .equatable()
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                    .simultaneousGesture(TapGesture().onEnded { onOpen?() }, including: onOpen == nil ? .none : .all)
                    .transition(.opacity)
                }
            }
        }
    }
}

private extension ColorViewModel {
    /// `==` is identity-only; the search card renders these fields too.
    func hasSameSearchContent(as other: ColorViewModel) -> Bool {
        id == other.id && name == other.name && HEX == other.HEX && color == other.color
            && isGenerated == other.isGenerated
    }
}

private extension PaletteViewModel {
    /// `==` is identity-only; the search card renders these fields too.
    func hasSameSearchContent(as other: PaletteViewModel) -> Bool {
        id == other.id && name == other.name && isGenerated == other.isGenerated
            && paletteColors.map(\.color) == other.paletteColors.map(\.color)
    }
}

private extension View {
    /// Widens a chip row into the surrounding `margin` and fades it out across
    /// that margin, so chips dissolve into the background before the safe
    /// area (on iPhone Duo's outer display, before the screen's edge).
    func chipRowFade(margin: CGFloat) -> some View {
        mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: margin)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: margin)
            }
        }
        .padding(.horizontal, -margin)
    }
}

#Preview {
    SearchView()
        .environmentObject(AppData())
        .environmentObject(SceneRouter())
}
