//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI

struct ColorsView: View {

    @State private var path = NavigationPath()
    @State private var colorForNewPalette: ColorViewModel?
    @State private var colorToDelete: ColorViewModel?
    @State private var colorToEdit: ColorBindingWrapper?
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    /// Selection order — the first-selected item decides whether the star
    /// button favorites or unfavorites the whole selection.
    @State private var selectionOrder: [UUID] = []
    @State private var showBulkDeleteAlert = false
    @AppStorage("colorsLayout") private var layoutRaw = ListLayout.normal.rawValue
    @AppStorage("colorsSort") private var sortRaw = LibrarySort.newestFirst.rawValue
    @AppStorage("colorsOriginFilter") private var originFilterRaw = LibraryOriginFilter.all.rawValue
    @State private var favoritesOnly = false
    /// Filtered + sorted colours, cached so scrolling / unrelated `AppData`
    /// publishes don't re-filter the library. nil until first computed.
    @State private var cachedDisplayed: [ColorViewModel]?
    /// True while a layout toggle animates, so the grid keeps cards for both
    /// layouts mounted only for that window.
    @State private var isMorphing = false
    @State private var morphToken = 0
    @EnvironmentObject var appData: AppData
    @EnvironmentObject private var router: SceneRouter

    struct ColorBindingWrapper: Identifiable {
        let id = UUID()
        let color: ColorViewModel
    }

    // MARK: - Display state

    private var layout: ListLayout { ListLayout(rawValue: layoutRaw) ?? .normal }
    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .newestFirst }
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
    private var displayedColors: [ColorViewModel] {
        cachedDisplayed ?? Self.displayed(from: appData.colors, favoritesOnly: favoritesOnly,
                                          origin: originFilter, sort: sort)
    }

    static func displayed(from colors: [ColorViewModel], favoritesOnly: Bool,
                          origin: LibraryOriginFilter, sort: LibrarySort) -> [ColorViewModel] {
        var items = colors
        if favoritesOnly { items = items.filter(\.isFavorite) }
        items = items.filter { origin.includes(isGenerated: $0.isGenerated) }
        if sort == .newestFirst { items.reverse() }
        return items
    }

    private func refreshDisplayed(from colors: [ColorViewModel]? = nil) {
        cachedDisplayed = Self.displayed(from: colors ?? appData.colors, favoritesOnly: favoritesOnly,
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
        let visibleIDs = Set(displayedColors.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }

    private var filteredEmptyTitle: String {
        switch (originFilter, favoritesOnly) {
        case (.all, true): "No Favorites"
        case (.created, true): "No Created Favorites"
        case (.generated, true): "No Generated Favorites"
        case (.all, false): "No Colors"
        case (.created, false): "No Created Colors"
        case (.generated, false): "No Generated Colors"
        }
    }

    private var filteredEmptyMessage: String {
        switch (originFilter, favoritesOnly) {
        case (.all, true): "Colors you mark as favorites will appear here."
        case (.created, true): "Created colors you mark as favorites will appear here."
        case (.generated, true): "Generated colors you mark as favorites will appear here."
        case (.all, false): "Create a color to add it to your library."
        case (.created, false): "Colors you create will appear here."
        case (.generated, false): "Colors generated with Apple Intelligence will appear here."
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            content
                .onReceive(appData.$colors) { refreshDisplayed(from: $0) }
                .onChange(of: sortRaw) { refreshDisplayed() }
                .onChange(of: originFilterRaw) { refreshDisplayed() }
                .onChange(of: favoritesOnly) { refreshDisplayed() }
                .navigationTitle(isSelecting ? "\(selectedIDs.count) Selected" : "Colors")
                .featureIntro(.colors)
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
                .sensoryFeedback(.selection, trigger: selectedIDs) { _, _ in isSelecting }
                .sensoryFeedback(.impact(weight: .light), trigger: isSelecting)
                .toolbar { toolbarContent }
                .sheet(isPresented: $router.isCreatingColor) {
                    NewColorView()
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .formPresentationSizing()
                }
                .sheet(item: $colorForNewPalette) { color in
                    NewPaletteView(preselectedColor: color)
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .formPresentationSizing()
                }
                .sheet(item: $colorToEdit) { colorBindingWrapper in
                    if let idx = appData.colors.firstIndex(where: { $0.id == colorBindingWrapper.color.id }) {
                        ColorEditView(
                            colorName: $appData.colors[idx].name,
                            hexCode: $appData.colors[idx].HEX,
                            colorValue: $appData.colors[idx].color
                        )
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .formPresentationSizing()
                    }
                }
                .alert("Delete Color", isPresented: $showDeleteAlert, presenting: colorToDelete) { color in
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring()) {
                            deleteColor(color)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { color in
                    let affected = palettes(for: color)
                    if affected.isEmpty {
                        Text("Are you sure you want to delete \"\(color.name)\"?")
                    } else {
                        Text("Deleting \"\(color.name)\" will also remove it from \(affected.count) palette\(affected.count == 1 ? "" : "s"): \(affected.map(\.name).joined(separator: ", ")).")
                    }
                }
                .alert("Delete Colors", isPresented: $showBulkDeleteAlert) {
                    Button("Delete", role: .destructive) {
                        deleteSelectedColors()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Delete \(selectedIDs.count) color\(selectedIDs.count == 1 ? "" : "s")? They will also be removed from any palettes that use them.")
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appData.colors.isEmpty {
            PaletteEmptyView(
                imageName: "circle.grid.cross.fill",
                title: "No colors yet",
                message: "Pick one, scan it from the world around you, or pull it from a photo.",
                actionTitle: "Add Color",
                action: { router.isCreatingColor = true }
            )
            .transition(.opacity)
        } else {
            libraryContent
                .overlay(alignment: .bottomTrailing) {
                    if !isSelecting {
                        // ⇧⌘N lives in the menu bar (PalettesCommands).
                        FloatingAddButton(title: "New Color") { router.isCreatingColor = true }
                            .padding(20)
                    }
                }
        }
    }

    fileprivate static func gridLayout(for layout: ListLayout) -> MorphingCardGrid {
        switch layout {
        case .compact:
            MorphingCardGrid(minColumnWidth: 160, maxColumnWidth: 280, rowHeight: 118, spacing: 12)
        case .normal:
            MorphingCardGrid(minColumnWidth: 340, maxColumnWidth: 560, rowHeight: 180, spacing: 20)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        let colors = displayedColors
        if colors.isEmpty {
            PaletteEmptyView(
                imageName: originFilter == .generated ? "sparkles" : (originFilter == .created ? "plus.circle" : "star"),
                title: filteredEmptyTitle,
                message: filteredEmptyMessage,
                actionTitle: "Show All Colors",
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
            ColorsGrid(
                colors: colors,
                layout: layout,
                isMorphing: isMorphing,
                isSelecting: isSelecting,
                selectedIDs: selectedIDs,
                card: { colorCard($0) }
            )
            .equatable()
        }
    }

    // MARK: - Cells

    /// One card per colour for both layouts. `ColorMorphCard` fills the frame that
    /// `MorphingCardGrid` animates, so toggling compact resizes and reflows each
    /// card in place; the selection, favourite and context-menu chrome is shared.
    @ViewBuilder
    private func colorCard(_ color: ColorViewModel) -> some View {
        ColorMorphCard(
            colorName: color.name,
            hexCode: color.HEX,
            color: color.color,
            isCompact: layout == .compact,
            isGenerated: color.isGenerated,
            isFavorite: color.isFavorite && !isSelecting,
            isSelecting: isSelecting,
            onView: { if !isSelecting { path.append(color) } },
            onCopy: { copyToClipboard(color.HEX, label: "Copied HEX") }
        )
        .equatable()
        .hoverEffect(.lift)
        .selectableCardChrome(
            isSelecting: isSelecting,
            isSelected: selectedIDs.contains(color.id),
            onToggle: { toggleSelection(color.id) }
        )
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if !isSelecting { path.append(color) }
        }
        // Drag the hex into another app or window.
        .draggable(color.HEX)
        .contextMenu { colorContextMenu(color) } preview: {
            ColorMorphCard(
                colorName: color.name,
                hexCode: color.HEX,
                color: color.color,
                isCompact: false,
                isGenerated: color.isGenerated
            )
            .frame(width: 360, height: 180)
            .padding(4)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func colorContextMenu(_ color: ColorViewModel) -> some View {
        Button {
            beginSelection(with: color.id)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }

        Button {
            colorToEdit = ColorBindingWrapper(color: color)
        } label: {
            Label("Edit Color", systemImage: "pencil")
        }

        Button {
            toggleFavorite(color)
        } label: {
            Label(color.isFavorite ? "Remove Favorite" : "Favorite",
                  systemImage: color.isFavorite ? "star.slash" : "star")
        }

        Button {
            copyToClipboard(color.HEX, label: "Copied HEX")
        } label: {
            Label("Copy as HEX", systemImage: "number")
        }

        Button {
            copyToClipboard(color.color.rgbString, label: "Copied RGB")
        } label: {
            Label("Copy as RGB", systemImage: "paintpalette")
        }

        Button {
            let cssName = color.name.lowercased().replacingOccurrences(of: " ", with: "-")
            let cssStr = "--\(cssName): \(color.HEX);"
            copyToClipboard(cssStr, label: "Copied CSS")
        } label: {
            Label("Export for CSS", systemImage: "curlybraces.square")
        }

        Button {
            ShareSheetPresenter.present(items: ["Check out this color: \(color.name) (\(color.HEX))"])
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }

        Button(role: .destructive) {
            colorToDelete = color
            showDeleteAlert = true
        } label: {
            Label("Delete Color", systemImage: "trash")
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
        if !appData.colors.isEmpty {
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
                    onShare: { shareSelectedColors(); exitSelection() },
                    onFavorite: {
                        appData.setColorsFavorite(selectedIDs, favorite: !firstSelectedIsFavorite)
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
                originFilter: originFilterBinding.animation(.spring(response: 0.3))
            )
        } label: {
            LibraryOptionsLabel()
        }
    }

    // MARK: - Data helpers

    private func palettes(for color: ColorViewModel) -> [PaletteViewModel] {
        appData.palettes.filter { palette in
            palette.hexCodes.contains(where: { $0.caseInsensitiveCompare(color.HEX) == .orderedSame })
        }
    }

    // MARK: - Actions

    private var firstSelectedIsFavorite: Bool {
        guard let firstID = selectionOrder.first(where: { selectedIDs.contains($0) }) else { return false }
        return appData.colors.first(where: { $0.id == firstID })?.isFavorite ?? false
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
        let visibleIDs = Set(displayedColors.map(\.id))
        if visibleIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(visibleIDs)
            selectionOrder.removeAll { visibleIDs.contains($0) }
        } else {
            selectionOrder.append(contentsOf: displayedColors.map(\.id).filter { !selectedIDs.contains($0) })
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

    private func toggleFavorite(_ color: ColorViewModel) {
        if let i = appData.colors.firstIndex(where: { $0.id == color.id }) {
            appData.colors[i].isFavorite.toggle()
        }
    }

    /// Removes a single color and strips it from any palettes that reference it,
    /// dropping palettes that become empty.
    private func deleteColor(_ color: ColorViewModel) {
        for i in appData.palettes.indices {
            if let colorIndex = appData.palettes[i].paletteColors.firstIndex(where: {
                $0.hex.caseInsensitiveCompare(color.HEX) == .orderedSame
            }) {
                appData.palettes[i].paletteColors.remove(at: colorIndex)
            }
        }
        appData.palettes.removeAll { $0.paletteColors.isEmpty }
        appData.colors.removeAll { $0.id == color.id }
    }

    private func deleteSelectedColors() {
        let colorsToDelete = appData.colors.filter { selectedIDs.contains($0.id) }
        withAnimation(.spring()) {
            for color in colorsToDelete {
                for i in appData.palettes.indices {
                    if let colorIndex = appData.palettes[i].paletteColors.firstIndex(where: {
                        $0.hex.caseInsensitiveCompare(color.HEX) == .orderedSame
                    }) {
                        appData.palettes[i].paletteColors.remove(at: colorIndex)
                    }
                }
            }
            appData.palettes.removeAll { $0.paletteColors.isEmpty }
            appData.colors.removeAll { selectedIDs.contains($0.id) }
        }
        exitSelection()
    }

    private func shareSelectedColors() {
        let selected = appData.colors.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let text = selected.map { "\($0.name) (\($0.HEX))" }.joined(separator: "\n")
        ShareSheetPresenter.present(items: [text])
    }

}


// MARK: - Grid

/// The scrolling card grid, split out and `Equatable` so `ColorsView` body
/// re-runs caused by unrelated `AppData` publishes (tab changes, coach marks)
/// don't re-evaluate it. Closures are ignored in `==`: `card` only reads state
/// that is also a field here (`layout`, `isSelecting`, `selectedIDs`) or boxed
/// `@State`, so equal fields render identically.
private struct ColorsGrid<Card: View>: View, Equatable {
    let colors: [ColorViewModel]
    let layout: ListLayout
    let isMorphing: Bool
    let isSelecting: Bool
    let selectedIDs: Set<UUID>
    let card: (ColorViewModel) -> Card

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.layout == rhs.layout && lhs.isMorphing == rhs.isMorphing
            && lhs.isSelecting == rhs.isSelecting && lhs.selectedIDs == rhs.selectedIDs
            && lhs.colors.count == rhs.colors.count
            && zip(lhs.colors, rhs.colors).allSatisfy { $0.hasSameContent(as: $1) }
    }

    var body: some View {
        ScrollView {
            LazyMorphingCardGrid(
                items: colors,
                grid: ColorsView.gridLayout(for: layout),
                morphTargets: isMorphing ? [ColorsView.gridLayout(for: layout == .compact ? .normal : .compact)] : [],
                content: card
            )
            .padding()
            .padding(.bottom, 88)
        }
    }
}

private extension ColorViewModel {
    /// `==` is identity-only; rendering depends on these fields too.
    func hasSameContent(as other: ColorViewModel) -> Bool {
        id == other.id && name == other.name && HEX == other.HEX && color == other.color
            && isFavorite == other.isFavorite && isGenerated == other.isGenerated
    }
}
