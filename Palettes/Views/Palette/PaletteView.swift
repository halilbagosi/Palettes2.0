import SwiftUI

struct PaletteView: View {

    @State private var isCreatingPalette = false
    @State private var path = NavigationPath()
    @State private var paletteToDelete: PaletteViewModel?
    @State private var paletteToEdit: PaletteViewModel?
    @State private var paletteToExport: PaletteViewModel?
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBulkDeleteAlert = false
    @AppStorage("palettesLayout") private var layoutRaw = ListLayout.normal.rawValue
    @AppStorage("palettesSort") private var sortRaw = LibrarySort.newestFirst.rawValue
    @State private var favoritesOnly = false
    @EnvironmentObject var appData: AppData

    // MARK: - Display state

    private var layout: ListLayout { ListLayout(rawValue: layoutRaw) ?? .normal }
    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .newestFirst }

    private var layoutBinding: Binding<ListLayout> {
        Binding(get: { layout }, set: { newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                layoutRaw = newValue.rawValue
            }
        })
    }

    private var sortBinding: Binding<LibrarySort> {
        Binding(get: { sort }, set: { sortRaw = $0.rawValue })
    }

    /// Filtered + sorted for display only; the stored array keeps creation order.
    private var displayedPalettes: [PaletteViewModel] {
        var items = appData.palettes
        if favoritesOnly { items = items.filter(\.isFavorite) }
        if sort == .newestFirst { items.reverse() }
        return items
    }

    private var allVisibleSelected: Bool {
        let visibleIDs = Set(displayedPalettes.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(isSelecting ? "\(selectedIDs.count) Selected" : "Palettes")
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
                .toolbar { toolbarContent }
                .sheet(isPresented: $isCreatingPalette) {
                    NewPaletteView()
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .formPresentationSizing()
                }
                .sheet(item: $paletteToEdit) { palette in
                    PaletteEditSheet(paletteName: palette.name, palette: palette)
                        .environmentObject(appData)
                        .formPresentationSizing()
                }
                .sheet(item: $paletteToExport) { palette in
                    ExportPaletteSheet(palette: palette)
                        .presentationDetents([.medium, .large])
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
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if appData.palettes.isEmpty {
            PaletteEmptyView(
                imageName: "swatchpalette.fill",
                message: "You currently have no palettes. Create one!",
                actionTitle: "Create Palette",
                action: { isCreatingPalette = true }
            )
            .transition(.opacity)
        } else {
            libraryContent
                .overlay(alignment: .bottomTrailing) {
                    if !isSelecting {
                        FloatingAddButton { isCreatingPalette = true }
                            .keyboardShortcut("n", modifiers: .command)
                            .padding(20)
                    }
                }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if displayedPalettes.isEmpty {
            ContentUnavailableView(
                "No Favorites",
                systemImage: "star",
                description: Text("Palettes you mark as favorites will appear here.")
            )
        } else {
            ScrollView {
                MorphingCardGrid(
                    minColumnWidth: layout == .compact ? 320 : 340,
                    maxColumnWidth: 560,
                    rowHeight: layout == .compact ? 96 : 180,
                    spacing: layout == .compact ? 10 : 20
                ) {
                    ForEach(displayedPalettes) { palette in
                        paletteCard(palette)
                    }
                }
                .padding()
                .padding(.bottom, 88)
            }
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
            onView: { if !isSelecting { path.append(palette) } },
            onCopy: { copyToClipboard(palette.hexCodes.joined(separator: ", "), label: "Copied HEX") }
        )
        .hoverEffect(.lift)
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                SelectionCheckmark(isSelected: selectedIDs.contains(palette.id))
            } else if palette.isFavorite {
                favoriteBadge
            }
        }
        .overlay {
            if isSelecting {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: selectedIDs.contains(palette.id) ? 3 : 0)
            }
        }
        .overlay {
            if isSelecting {
                Color.white.opacity(0.001)
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .onTapGesture { toggleSelection(palette.id) }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if !isSelecting { path.append(palette) }
        }
        .contextMenu { paletteContextMenu(palette) } preview: {
            PaletteMorphCard(paletteName: palette.name, colors: palette.colors, isCompact: false)
                .frame(width: 360, height: 180)
                .padding(4)
        }
    }

    private var favoriteBadge: some View {
        Image(systemName: "star.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.yellow)
            .padding(7)
            .background(.black.opacity(0.18), in: .circle)
            .padding(10)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func paletteContextMenu(_ palette: PaletteViewModel) -> some View {
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
                presentShare(items: [image])
            }
        } label: {
            Label("Export as PNG", systemImage: "photo")
        }

        Button {
            let textToShare = "Check out this palette: \(palette.name)\n" + palette.hexCodes.joined(separator: ", ")
            presentShare(items: [textToShare])
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
        if !appData.palettes.isEmpty {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button(allVisibleSelected ? "Deselect All" : "Select All") {
                        toggleSelectAll()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        exitSelection()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    optionsMenu
                }
                SelectionBottomBar(
                    count: selectedIDs.count,
                    onDelete: { showBulkDeleteAlert = true },
                    onShare: { shareSelectedPalettes(); exitSelection() },
                    onFavorite: { appData.setPalettesFavorite(selectedIDs); exitSelection() }
                )
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") {
                        withAnimation { isSelecting = true }
                    }
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
                favoritesOnly: $favoritesOnly.animation(.spring(response: 0.3))
            )
        } label: {
            Image(systemName: "ellipsis")
        }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleSelectAll() {
        let visibleIDs = Set(displayedPalettes.map(\.id))
        if visibleIDs.isSubset(of: selectedIDs) {
            selectedIDs.subtract(visibleIDs)
        } else {
            selectedIDs.formUnion(visibleIDs)
        }
    }

    private func exitSelection() {
        withAnimation {
            isSelecting = false
            selectedIDs = []
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
        presentShare(items: [text])
    }

    private func presentShare(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
