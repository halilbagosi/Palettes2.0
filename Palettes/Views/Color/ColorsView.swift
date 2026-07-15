//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI

struct ColorsView: View {

    @State private var isCreatingColor = false
    @State private var path = NavigationPath()
    @State private var colorForNewPalette: ColorViewModel?
    @State private var colorToDelete: ColorViewModel?
    @State private var colorToEdit: ColorBindingWrapper?
    @State private var showDeleteAlert = false
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showBulkDeleteAlert = false
    @AppStorage("colorsLayout") private var layoutRaw = ListLayout.normal.rawValue
    @AppStorage("colorsSort") private var sortRaw = LibrarySort.newestFirst.rawValue
    @State private var favoritesOnly = false
    @EnvironmentObject var appData: AppData

    struct ColorBindingWrapper: Identifiable {
        let id = UUID()
        let color: ColorViewModel
    }

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
    private var displayedColors: [ColorViewModel] {
        var items = appData.colors
        if favoritesOnly { items = items.filter(\.isFavorite) }
        if sort == .newestFirst { items.reverse() }
        return items
    }

    private var allVisibleSelected: Bool {
        let visibleIDs = Set(displayedColors.map(\.id))
        return !visibleIDs.isEmpty && visibleIDs.isSubset(of: selectedIDs)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle(isSelecting ? "\(selectedIDs.count) Selected" : "Colors")
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .toolbar(isSelecting ? .hidden : .automatic, for: .tabBar)
                .toolbar { toolbarContent }
                .sheet(isPresented: $isCreatingColor) {
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
                message: "You currently have no colors. Create one!",
                actionTitle: "Create Color",
                action: { isCreatingColor = true }
            )
            .transition(.opacity)
        } else {
            libraryContent
                .overlay(alignment: .bottomTrailing) {
                    if !isSelecting {
                        FloatingAddButton { isCreatingColor = true }
                            .keyboardShortcut("n", modifiers: [.command, .shift])
                            .padding(20)
                    }
                }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        if displayedColors.isEmpty {
            ContentUnavailableView(
                "No Favorites",
                systemImage: "star",
                description: Text("Colors you mark as favorites will appear here.")
            )
        } else {
            ScrollView {
                MorphingCardGrid(
                    minColumnWidth: layout == .compact ? 160 : 340,
                    maxColumnWidth: layout == .compact ? 280 : 560,
                    rowHeight: layout == .compact ? 118 : 180,
                    spacing: layout == .compact ? 12 : 20
                ) {
                    ForEach(displayedColors) { color in
                        colorCard(color)
                    }
                }
                .padding()
                .padding(.bottom, 88)
            }
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
            onView: { if !isSelecting { path.append(color) } },
            onCopy: { copyToClipboard(color.HEX, label: "Copied HEX") }
        )
        .hoverEffect(.lift)
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                SelectionCheckmark(isSelected: selectedIDs.contains(color.id))
            } else if color.isFavorite {
                favoriteBadge
            }
        }
        .overlay {
            if isSelecting {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: selectedIDs.contains(color.id) ? 3 : 0)
            }
        }
        .overlay {
            if isSelecting {
                Color.white.opacity(0.001)
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .onTapGesture { toggleSelection(color.id) }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture {
            if !isSelecting { path.append(color) }
        }
        .contextMenu { colorContextMenu(color) } preview: {
            ColorMorphCard(
                colorName: color.name,
                hexCode: color.HEX,
                color: color.color,
                isCompact: false
            )
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
    private func colorContextMenu(_ color: ColorViewModel) -> some View {
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
            presentShare(items: ["Check out this color: \(color.name) (\(color.HEX))"])
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
        if !appData.colors.isEmpty {
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
                    onShare: { shareSelectedColors(); exitSelection() },
                    onFavorite: { appData.setColorsFavorite(selectedIDs); exitSelection() }
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

    // MARK: - Data helpers

    private func palettes(for color: ColorViewModel) -> [PaletteViewModel] {
        appData.palettes.filter { palette in
            palette.hexCodes.contains(where: { $0.caseInsensitiveCompare(color.HEX) == .orderedSame })
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
        let visibleIDs = Set(displayedColors.map(\.id))
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

    private func toggleFavorite(_ color: ColorViewModel) {
        if let i = appData.colors.firstIndex(where: { $0.id == color.id }) {
            appData.colors[i].isFavorite.toggle()
        }
    }

    /// Removes a single color and strips it from any palettes that reference it,
    /// dropping palettes that become empty.
    private func deleteColor(_ color: ColorViewModel) {
        for i in appData.palettes.indices {
            if let colorIndex = appData.palettes[i].hexCodes.firstIndex(where: {
                $0.caseInsensitiveCompare(color.HEX) == .orderedSame
            }) {
                appData.palettes[i].colors.remove(at: colorIndex)
                appData.palettes[i].hexCodes.remove(at: colorIndex)
                appData.palettes[i].colorNames.remove(at: colorIndex)
            }
        }
        appData.palettes.removeAll { $0.colors.isEmpty }
        appData.colors.removeAll { $0.id == color.id }
    }

    private func deleteSelectedColors() {
        let colorsToDelete = appData.colors.filter { selectedIDs.contains($0.id) }
        withAnimation(.spring()) {
            for color in colorsToDelete {
                for i in appData.palettes.indices {
                    if let colorIndex = appData.palettes[i].hexCodes.firstIndex(where: {
                        $0.caseInsensitiveCompare(color.HEX) == .orderedSame
                    }) {
                        appData.palettes[i].colors.remove(at: colorIndex)
                        appData.palettes[i].hexCodes.remove(at: colorIndex)
                        appData.palettes[i].colorNames.remove(at: colorIndex)
                    }
                }
            }
            appData.palettes.removeAll { $0.colors.isEmpty }
            appData.colors.removeAll { selectedIDs.contains($0.id) }
        }
        exitSelection()
    }

    private func shareSelectedColors() {
        let selected = appData.colors.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let text = selected.map { "\($0.name) (\($0.HEX))" }.joined(separator: "\n")
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
