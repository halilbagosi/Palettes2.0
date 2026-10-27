import SwiftUI

enum OptionsTourGate {
    /// The return tour starts only once the library is showing: flag armed,
    /// stack empty, and the Palettes tab selected. Otherwise it stays armed.
    nonisolated static func shouldPresent(flag: Bool, pathIsEmpty: Bool, selectedTabIsPalettes: Bool) -> Bool {
        flag && pathIsEmpty && selectedTabIsPalettes
    }
}

struct PaletteView: View {

    @State private var path = NavigationPath()
    @Environment(\.selectedTab) private var selectedTab
    @State private var paletteToDelete: PaletteViewModel?
    @State private var paletteToEdit: PaletteViewModel?
    @State private var paletteToExport: PaletteViewModel?
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    /// Selection order — the first-selected item decides whether the star
    /// button favorites or unfavorites the whole selection.
    @State private var selectionOrder: [UUID] = []
    @State private var showBulkDeleteAlert = false
    @AppStorage("palettesLayout") private var layoutRaw = ListLayout.normal.rawValue
    @AppStorage("palettesSort") private var sortRaw = LibrarySort.newestFirst.rawValue
    @AppStorage("palettesOriginFilter") private var originFilterRaw = LibraryOriginFilter.all.rawValue
    @State private var favoritesOnly = false
    /// Filtered + sorted palettes, cached so scrolling / unrelated `AppData`
    /// publishes don't re-filter and re-sort the library. nil until first computed.
    @State private var cachedDisplayed: [PaletteViewModel]?
    /// True while a layout toggle animates, so the grid keeps cards for both
    /// layouts mounted only for that window.
    @State private var isMorphing = false
    @State private var morphToken = 0
    /// The one-time options card after onboarding's "Start creating".
    @State private var showsOptionsTour = false
    @State private var optionsTourTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var appData: AppData
    @EnvironmentObject private var router: SceneRouter

    // MARK: - Display state

    private var layout: ListLayout { ListLayout(rawValue: layoutRaw) ?? .normal }
    /// Hue order isn't offered here; a stored one falls back to newest first.
    private var sort: LibrarySort {
        LibrarySort(rawValue: sortRaw).flatMap { LibrarySort.paletteCases.contains($0) ? $0 : nil } ?? .newestFirst
    }
    private var originFilter: LibraryOriginFilter {
        LibraryOriginFilter(rawValue: originFilterRaw) ?? .all
    }

    private var layoutBinding: Binding<ListLayout> {
        Binding(get: { layout }, set: { newValue in
            // Open the morph window first so the target layout's extra cards are
            // already mounted (with a frame) when the animated change lands.
            beginMorphWindow()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    layoutRaw = newValue.rawValue
                }
            }
        })
    }

    private var sortBinding: Binding<LibrarySort> {
        Binding(get: { sort }, set: { sortRaw = $0.rawValue; refreshDisplayed() })
    }

    private var originFilterBinding: Binding<LibraryOriginFilter> {
        Binding(get: { originFilter }, set: { originFilterRaw = $0.rawValue; refreshDisplayed() })
    }

    private var favoritesOnlyBinding: Binding<Bool> {
        Binding(get: { favoritesOnly }, set: { newValue in
            favoritesOnly = newValue
            refreshDisplayed()
        })
    }

    /// Filtered + sorted for display only; the stored array keeps creation order.
    private var displayedPalettes: [PaletteViewModel] {
        cachedDisplayed ?? Self.displayed(from: appData.palettes, favoritesOnly: favoritesOnly,
                                          origin: originFilter, sort: sort)
    }

    static func displayed(from palettes: [PaletteViewModel], favoritesOnly: Bool,
                          origin: LibraryOriginFilter, sort: LibrarySort) -> [PaletteViewModel] {
        var items = palettes
        if favoritesOnly { items = items.filter(\.isFavorite) }
        items = items.filter { origin.includes(isGenerated: $0.isGenerated) }
        return sort.ordered(items) { HueOrder.key(forHexes: $0.hexCodes) }
    }

    private func refreshDisplayed(from palettes: [PaletteViewModel]? = nil) {
        cachedDisplayed = Self.displayed(from: palettes ?? appData.palettes, favoritesOnly: favoritesOnly,
                                         origin: originFilter, sort: sort)
    }

    /// Keeps both layouts' cards mounted just long enough for the morph.
    private func beginMorphWindow() {
        isMorphing = true
        morphToken += 1
        let token = morphToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            if token == morphToken { isMorphing = false }
        }
    }

    private var allVisibleSelected: Bool {
        let visibleIDs = Set(displayedPalettes.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }

    private var filteredEmptyTitle: String {
        switch (originFilter, favoritesOnly) {
        case (.all, true): "No Favorites"
        case (.created, true): "No Created Favorites"
        case (.generated, true): "No Generated Favorites"
        case (.all, false): "No Palettes"
        case (.created, false): "No Created Palettes"
        case (.generated, false): "No Generated Palettes"
        }
    }

    private var filteredEmptyMessage: String {
        switch (originFilter, favoritesOnly) {
        case (.all, true): "Palettes you mark as favorites will appear here."
        case (.created, true): "Created palettes you mark as favorites will appear here."
        case (.generated, true): "Generated palettes you mark as favorites will appear here."
        case (.all, false): "Create a palette to add it to your library."
        case (.created, false): "Palettes you create will appear here."
        case (.generated, false): "Palettes generated with Apple Intelligence will appear here."
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            content
                .onReceive(appData.$palettes) { refreshDisplayed(from: $0) }
                .onChange(of: sortRaw) { refreshDisplayed() }
                .onChange(of: originFilterRaw) { refreshDisplayed() }
                .onChange(of: favoritesOnly) { refreshDisplayed() }
                .libraryTitle("Palette", count: displayedPalettes.count, selectedCount: isSelecting ? selectedIDs.count : nil)
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
                .sensoryFeedback(.selection, trigger: selectedIDs) { _, _ in isSelecting }
                .sensoryFeedback(.impact(weight: .light), trigger: isSelecting)
                .toolbar { toolbarContent }
                .sheet(isPresented: $router.isCreatingPalette) {
                    NewPaletteView()
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .formPresentationSizing()
                }
                .sheet(item: $paletteToEdit) { palette in
                    PaletteEditSheet(palette: palette)
                        .environmentObject(appData)
                        .formPresentationSizing()
                }
                .sheet(item: $paletteToExport) { palette in
                    ExportPaletteSheet(palette: palette)
                        .presentationDetents([.large])
                }
                .alert("Delete Palette", isPresented: $showDeleteAlert, presenting: paletteToDelete) { palette in
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring()) {
                            appData.palettes.removeAll(where: { $0.id == palette.id })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { palette in
                    Text("Are you sure you want to delete \"\(palette.name)\"?")
                }
                .alert("Delete Palettes", isPresented: $showBulkDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring()) {
                            appData.palettes.removeAll { selectedIDs.contains($0.id) }
                        }
                        exitSelection()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete \(selectedIDs.count) palette\(selectedIDs.count == 1 ? "" : "s")? This cannot be undone.")
                }
                .overlay(alignment: .topTrailing) {
                    if showsOptionsTour {
                        LibraryOptionsTourCard(
                            layout: layoutBinding,
                            sort: sortBinding,
                            favoritesOnly: favoritesOnlyBinding.animation(.spring(response: 0.3)),
                            originFilter: originFilterBinding.animation(.spring(response: 0.3)),
                            sorts: LibrarySort.paletteCases,
                            onDone: endOptionsTour
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        // Grows out of the options button it describes.
                        .transition(reduceMotion
                            ? .opacity
                            : .scale(scale: 0.6, anchor: .topTrailing).combined(with: .opacity))
                    }
                }
                .onReceive(appData.$libraryOptionsTourPending) { pending in
                    if pending { beginOptionsTour() }
                }
                // Leaving the tab puts the stack away, so coming back (or the
                // tab bar swapping chrome) never replays a pushed detail.
                .onChange(of: selectedTab) { _, tab in
                    if tab != .palettes {
                        if !path.isEmpty { path = NavigationPath() }
                    } else if OptionsTourGate.shouldPresent(
                        flag: appData.libraryOptionsTourOnReturn,
                        pathIsEmpty: path.isEmpty,
                        selectedTabIsPalettes: true
                    ) {
                        appData.libraryOptionsTourOnReturn = false
                        showOptionsTour(after: .milliseconds(450))
                    }
                }
                .onChange(of: path.count) { _, count in
                    // Opening a palette puts the card away.
                    if count > 0, showsOptionsTour { endOptionsTour() }
                    // Back at the library after closing the extras sheet with ×.
                    // Left armed while another tab is showing; it runs on return.
                    if OptionsTourGate.shouldPresent(
                        flag: appData.libraryOptionsTourOnReturn,
                        pathIsEmpty: count == 0,
                        selectedTabIsPalettes: selectedTab == .palettes
                    ) {
                        appData.libraryOptionsTourOnReturn = false
                        showOptionsTour(after: .milliseconds(450))
                    }
                }
                .onReceive(appData.$pendingOpenPaletteID) { id in
                    guard let id, let palette = appData.palettes.first(where: { $0.id == id }) else { return }
                    appData.pendingOpenPaletteID = nil
                    path = NavigationPath([palette])
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appData.palettes.isEmpty {
            PaletteEmptyView(
                imageName: "swatchpalette.fill",
                title: "No palettes yet",
                message: "Capture colors you love and mix them into your first palette.",
                actionTitle: "Create Palette",
                action: { router.isCreatingPalette = true }
            )
            .transition(.opacity)
        } else {
            libraryContent
                .overlay(alignment: .bottomTrailing) {
                    if !isSelecting {
                        // ⌘N lives in the menu bar (PalettesCommands).
                        FloatingAddButton(title: "New Palette") { router.isCreatingPalette = true }
                            .padding(20)
                    }
                }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if displayedPalettes.isEmpty {
            PaletteEmptyView(
                imageName: originFilter == .generated ? "sparkles" : (originFilter == .created ? "plus.circle" : "star"),
                title: filteredEmptyTitle,
                message: filteredEmptyMessage,
                actionTitle: "Show All Palettes",
                actionImage: "line.3.horizontal.decrease.circle",
                compact: true
            ) {
                withAnimation(.spring(response: 0.3)) {
                    favoritesOnly = false
                    originFilterRaw = LibraryOriginFilter.all.rawValue
                    refreshDisplayed()
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            // The layout binding always applies its own withAnimation (also for
            // the options card's Toggle), so no implicit animation is needed here.
            PalettesGrid(
                palettes: displayedPalettes,
                layout: layout,
                isMorphing: isMorphing,
                isSelecting: isSelecting,
                selectedIDs: selectedIDs,
                card: { paletteCard($0) }
            )
            .equatable()
        }
    }

    fileprivate static func gridLayout(for layout: ListLayout) -> MorphingCardGrid {
        switch layout {
        case .compact:
            MorphingCardGrid(minColumnWidth: 320, maxColumnWidth: 560, rowHeight: 108, spacing: 10)
        case .normal:
            MorphingCardGrid(minColumnWidth: 340, maxColumnWidth: 560, rowHeight: 180, spacing: 20)
        }
    }

    // MARK: - Cells

    /// One card per palette for both layouts. `PaletteMorphCard` fills the frame
    /// that `MorphingCardGrid` animates, so toggling compact resizes and reflows
    /// each card in place; the selection, favourite and context-menu chrome is
    /// shared.
    @ViewBuilder
    private func paletteCard(_ palette: PaletteViewModel) -> some View {
        PaletteMorphCard(
            paletteName: palette.name,
            colors: palette.colors,
            isCompact: layout == .compact,
            isGenerated: palette.isGenerated,
            isFavorite: palette.isFavorite && !isSelecting,
            isSelecting: isSelecting,
            onCopy: { copyToClipboard(palette.hexCodes.joined(separator: ", "), label: "Copied HEX") }
        )
        .equatable()
        .hoverEffect(.lift)
        .selectableCardChrome(
            isSelecting: isSelecting,
            isSelected: selectedIDs.contains(palette.id),
            onToggle: { toggleSelection(palette.id) }
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if !isSelecting { path.append(palette) }
        }
        // Drag into Notes, Freeform, a design tool or another Palettes window.
        .draggable(palette.dragText)
        .contextMenu { paletteContextMenu(palette) } preview: {
            PaletteMorphCard(
                paletteName: palette.name,
                colors: palette.colors,
                isCompact: false,
                isGenerated: palette.isGenerated
            )
                .frame(width: 360, height: 180)
                .padding(4)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func paletteContextMenu(_ palette: PaletteViewModel) -> some View {
        Button {
            beginSelection(with: palette.id)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }

        Button {
            paletteToEdit = palette
        } label: {
            Label("Edit Palette", systemImage: "pencil")
        }

        Button {
            toggleFavorite(palette)
        } label: {
            Label(palette.isFavorite ? "Remove Favorite" : "Favorite",
                  systemImage: palette.isFavorite ? "star.slash" : "star")
        }

        Button {
            let hexes = palette.hexCodes.joined(separator: ", ")
            copyToClipboard(hexes, label: "Copied HEX")
        } label: {
            Label("Copy as HEX", systemImage: "number")
        }

        Button {
            let rgbs = palette.colors.map { $0.rgbString }.joined(separator: " | ")
            copyToClipboard(rgbs, label: "Copied RGB")
        } label: {
            Label("Copy as RGB", systemImage: "paintpalette")
        }

        Button {
            let safePaletteName = palette.name.lowercased().replacingOccurrences(of: " ", with: "-")
            var cssLines = ["/* \(palette.name) */", ":root {"]
            for (index, colorName) in palette.colorNames.enumerated() {
                if index < palette.hexCodes.count {
                    let safeColorName = colorName.lowercased().replacingOccurrences(of: " ", with: "-")
                    let finalName = safeColorName.isEmpty ? "color-\(index + 1)" : safeColorName
                    cssLines.append("  --\(safePaletteName)-\(finalName): \(palette.hexCodes[index]);")
                }
            }
            cssLines.append("}")
            copyToClipboard(cssLines.joined(separator: "\n"), label: "Copied CSS")
        } label: {
            Label("Export as CSS", systemImage: "curlybraces.square")
        }

        Button {
            let colorVMs = palette.colors.indices.map { index -> ColorViewModel in
                let hex = index < palette.hexCodes.count ? palette.hexCodes[index] : ""
                let name = index < palette.colorNames.count ? palette.colorNames[index] : "Color \(index + 1)"
                return ColorViewModel(name: name, color: palette.colors[index], HEX: hex, usedInPalette: true)
            }
            if let image = PaletteImageRenderer.renderImage(for: palette, colors: colorVMs) {
                ShareSheetPresenter.present(items: [image])
            }
        } label: {
            Label("Export as PNG", systemImage: "photo")
        }

        Button {
            let textToShare = "Check out this palette: \(palette.name)\n" + palette.hexCodes.joined(separator: ", ")
            ShareSheetPresenter.present(items: [textToShare])
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button {
            paletteToExport = palette
        } label: {
            Label("Export…", systemImage: "square.and.arrow.up.on.square")
        }

        Button(role: .destructive) {
            paletteToDelete = palette
            showDeleteAlert = true
        } label: {
            Label("Delete Palette", systemImage: "trash")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                SettingsToolbarButton()
            }
        }
        if !appData.palettes.isEmpty {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    SelectAllButton(allSelected: allVisibleSelected, action: toggleSelectAll)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        exitSelection()
                    } label: {
                        Label("Done Selecting", systemImage: "xmark")
                    }
                    optionsMenu
                }
                SelectionBottomBar(
                    count: selectedIDs.count,
                    favoriteFilled: firstSelectedIsFavorite,
                    onDelete: { showBulkDeleteAlert = true },
                    onShare: { shareSelectedPalettes(); exitSelection() },
                    onFavorite: {
                        appData.setPalettesFavorite(selectedIDs, favorite: !firstSelectedIsFavorite)
                        exitSelection()
                    }
                )
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    SelectButton { withAnimation { isSelecting = true } }
                }
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    optionsMenu
                }
            }
        }
    }

    private var optionsMenu: some View {
        Menu {
            LibraryOptionsMenu(
                layout: layoutBinding,
                sort: sortBinding,
                favoritesOnly: favoritesOnlyBinding.animation(.spring(response: 0.3)),
                originFilter: originFilterBinding.animation(.spring(response: 0.3)),
                sorts: LibrarySort.paletteCases
            )
        } label: {
            LibraryOptionsLabel()
                .symbolEffect(.bounce, value: showsOptionsTour)
        }
    }

    // MARK: - Options tour

    /// Waits for the extras sheet to finish closing, returns to the library,
    /// then brings in the options card.
    private func beginOptionsTour() {
        appData.libraryOptionsTourPending = false
        optionsTourTask?.cancel()
        optionsTourTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            if !path.isEmpty {
                path = NavigationPath()
                try? await Task.sleep(for: .milliseconds(550))
                guard !Task.isCancelled else { return }
            }
            presentOptionsTour()
        }
    }

    /// Brings in the card over the library as it is, after `delay` (the pop
    /// back to the library finishing).
    private func showOptionsTour(after delay: Duration) {
        appData.libraryOptionsTourPending = false
        optionsTourTask?.cancel()
        optionsTourTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, path.isEmpty else { return }
            presentOptionsTour()
        }
    }

    private func presentOptionsTour() {
        exitSelection()
        guard !appData.palettes.isEmpty else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(duration: 0.5, bounce: 0.2)) {
            showsOptionsTour = true
        }
    }

    private func endOptionsTour() {
        optionsTourTask?.cancel()
        withAnimation(reduceMotion ? .easeInOut(duration: 0.25) : .spring(duration: 0.35, bounce: 0)) {
            showsOptionsTour = false
        }
    }

    // MARK: - Actions

    private var firstSelectedIsFavorite: Bool {
        guard let firstID = selectionOrder.first(where: { selectedIDs.contains($0) }) else { return false }
        return appData.palettes.first(where: { $0.id == firstID })?.isFavorite ?? false
    }

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            selectionOrder.removeAll { $0 == id }
        } else {
            selectedIDs.insert(id)
            selectionOrder.append(id)
        }
    }

    private func toggleSelectAll() {
        let visibleIDs = Set(displayedPalettes.map(\.id))
        if visibleIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(visibleIDs)
            selectionOrder.removeAll { visibleIDs.contains($0) }
        } else {
            selectionOrder.append(contentsOf: displayedPalettes.map(\.id).filter { !selectedIDs.contains($0) })
            selectedIDs.formUnion(visibleIDs)
        }
    }

    private func beginSelection(with id: UUID) {
        withAnimation {
            isSelecting = true
            selectedIDs = [id]
            selectionOrder = [id]
        }
    }

    private func exitSelection() {
        withAnimation {
            isSelecting = false
            selectedIDs = []
            selectionOrder = []
        }
    }

    private func toggleFavorite(_ palette: PaletteViewModel) {
        if let i = appData.palettes.firstIndex(where: { $0.id == palette.id }) {
            appData.palettes[i].isFavorite.toggle()
        }
    }

    private func shareSelectedPalettes() {
        let selected = appData.palettes.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let text = selected.map { palette in
            "\(palette.name)\n" + palette.hexCodes.joined(separator: ", ")
        }.joined(separator: "\n\n")
        ShareSheetPresenter.present(items: [text])
    }

}

// MARK: - Grid

/// The scrolling card grid, split out and `Equatable` so `PaletteView` body
/// re-runs caused by unrelated `AppData` publishes (tab changes, coach marks)
/// don't re-evaluate it. Closures are ignored in `==`: `card` only reads state
/// that is also a field here (`layout`, `isSelecting`, `selectedIDs`) or boxed
/// `@State`, so equal fields render identically.
private struct PalettesGrid<Card: View>: View, Equatable {
    let palettes: [PaletteViewModel]
    let layout: ListLayout
    let isMorphing: Bool
    let isSelecting: Bool
    let selectedIDs: Set<UUID>
    let card: (PaletteViewModel) -> Card

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.layout == rhs.layout && lhs.isMorphing == rhs.isMorphing
            && lhs.isSelecting == rhs.isSelecting && lhs.selectedIDs == rhs.selectedIDs
            && lhs.palettes.count == rhs.palettes.count
            && zip(lhs.palettes, rhs.palettes).allSatisfy { $0.hasSameContent(as: $1) }
    }

    var body: some View {
        ScrollView {
            LazyMorphingCardGrid(
                items: palettes,
                grid: PaletteView.gridLayout(for: layout),
                morphTargets: isMorphing ? [PaletteView.gridLayout(for: layout == .compact ? .normal : .compact)] : [],
                content: card
            )
            .padding()
            .padding(.bottom, 88)
        }
    }
}

private extension PaletteViewModel {
    /// `==` is identity-only; rendering depends on these fields too.
    func hasSameContent(as other: PaletteViewModel) -> Bool {
        id == other.id && name == other.name && paletteColors == other.paletteColors
            && isFavorite == other.isFavorite && isGenerated == other.isGenerated
    }
}
