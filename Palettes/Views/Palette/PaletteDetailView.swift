//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 14.2.26.
//
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers



// MARK: - New Gallery-Style Palette Detail View

struct PaletteDetailView: View {
    let paletteName: String
    let palette: PaletteViewModel
    @EnvironmentObject var appData: AppData
    @State private var isEditingPalette = false
    @State private var editColorIndex: Int?
    @State private var taggingColorIndex: Int?
    @State private var showDeleteAlert = false
    @State private var isExporting = false
    /// True while a color's context menu is open (tracked from its preview).
    @State private var menuOpen = false
    /// iPhone Duo's fold while half open (see `FoldCompat`).
    @State private var fold: Fold?
    /// Ties the strip and each card across the folded and unfolded layouts,
    /// so they move and resize into place when the device folds.
    @Namespace private var foldNamespace
    /// The color being dragged to a new place in the palette.
    @State private var draggedColorID: UUID?
    /// Bumped on each reorder step, for a selection tick.
    @State private var reorderTick = 0
    @Environment(\.dismiss) var dismiss

    private struct ColorBindingWrapper: Identifiable {
        let id: Int
    }

    private struct TaggingTarget: Identifiable {
        let id: Int
    }

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == palette.id })
    }

    /// Anything presented over the detail; the onboarding extras sheet waits for it to clear.
    private var isBusyWithOtherUI: Bool {
        menuOpen || taggingColorIndex != nil || editColorIndex != nil
            || isEditingPalette || isExporting || showDeleteAlert
    }

    private var livePalette: PaletteViewModel {
        if let idx = paletteIndex { return appData.palettes[idx] }
        return palette
    }

    private func colorViewModel(at index: Int, from pal: PaletteViewModel) -> ColorViewModel {
        let hex = index < pal.hexCodes.count ? pal.hexCodes[index] : ""
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            return existing
        }
        let name = index < pal.colorNames.count ? pal.colorNames[index] : "Color \(index + 1)"
        return ColorViewModel(name: name, color: pal.colors[index], HEX: hex, usedInPalette: true)
    }

    var body: some View {
        detailContent
            .navigationTitle(livePalette.name)
            .sensoryFeedback(.selection, trigger: reorderTick)
            .onDisappear { draggedColorID = nil }
            .onboardingCoachMark(for: palette.id)
            .onboardingExtras(for: livePalette, isBusy: isBusyWithOtherUI)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        savePaletteAsPNG()
                    } label: {
                        Label("Export as PNG", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .overflowMenu {
                Button {
                    isEditingPalette = true
                } label: {
                    Label("Edit Palette", systemImage: "pencil")
                }

                Button {
                    toggleFavorite()
                } label: {
                    Label(livePalette.isFavorite ? "Remove Favorite" : "Favorite",
                          systemImage: livePalette.isFavorite ? "star.slash" : "star")
                }

                Button {
                    let textToShare = "Check out this palette: \(livePalette.name)\n" + livePalette.hexCodes.joined(separator: ", ")
                    ShareSheetPresenter.present(items: [textToShare])
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button {
                    isExporting = true
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up.on.square")
                }

                Button {
                    savePaletteAsPNG()
                } label: {
                    Label("Export as PNG", systemImage: "photo")
                }

                Button {
                    let hexes = livePalette.hexCodes.joined(separator: ", ")
                    copyToClipboard(hexes, label: "Copied HEX")
                } label: {
                    Label("Copy as HEX", systemImage: "number")
                }

                Button {
                    let rgbs = livePalette.colors.map { $0.rgbString }.joined(separator: " | ")
                    copyToClipboard(rgbs, label: "Copied RGB")
                } label: {
                    Label("Copy as RGB", systemImage: "paintpalette")
                }

                Button {
                    let safePaletteName = livePalette.name.lowercased().replacingOccurrences(of: " ", with: "-")
                    var cssLines = ["/* \(livePalette.name) */", ":root {"]
                    for (index, colorName) in livePalette.colorNames.enumerated() {
                        if index < livePalette.hexCodes.count {
                            let safeColorName = colorName.lowercased().replacingOccurrences(of: " ", with: "-")
                            let finalName = safeColorName.isEmpty ? "color-\(index + 1)" : safeColorName
                            cssLines.append("  --\(safePaletteName)-\(finalName): \(livePalette.hexCodes[index]);")
                        }
                    }
                    cssLines.append("}")
                    copyToClipboard(cssLines.joined(separator: "\n"), label: "Copied CSS")
                } label: {
                    Label("Export as CSS", systemImage: "curlybraces.square")
                }

                Divider()

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete Palette", systemImage: "trash")
                }
            }
            .sheet(isPresented: $isEditingPalette) {
                PaletteEditSheet(paletteName: livePalette.name, palette: palette)
                    .environmentObject(appData)
                    .formPresentationSizing()
            }
            .sheet(item: Binding(
                get: {
                    if let index = editColorIndex,
                       index < livePalette.paletteColors.count {
                        return ColorBindingWrapper(id: index)
                    }
                    return nil
                },
                set: { newValue in
                    if newValue == nil {
                        editColorIndex = nil
                    }
                }
            )) { wrapper in
                if let paletteIdx = paletteIndex,
                   wrapper.id < appData.palettes[paletteIdx].paletteColors.count {
                    ColorEditView(
                        colorName: $appData.palettes[paletteIdx].paletteColors[wrapper.id].name,
                        hexCode: $appData.palettes[paletteIdx].paletteColors[wrapper.id].hex,
                        colorValue: $appData.palettes[paletteIdx].paletteColors[wrapper.id].color,
                        promptOnNameMatch: true,
                        onSaveWithAction: { isOverwrite in
                            syncEditedPaletteColor(at: wrapper.id, isOverwrite: isOverwrite)
                        }
                    )
                    .environmentObject(appData)
                    .presentationDetents([.large])
                    .formPresentationSizing()
                }
            }
            .sheet(item: Binding(
                get: { taggingColorIndex.map { TaggingTarget(id: $0) } },
                set: { newValue in taggingColorIndex = newValue?.id }
            )) { target in
                RolePickerSheet(
                    currentRole: target.id < livePalette.paletteColors.count ? livePalette.paletteColors[target.id].role : nil,
                    palette: livePalette,
                    colorIndex: target.id
                )
                .environmentObject(appData)
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isExporting) {
                ExportPaletteSheet(palette: livePalette)
                    .presentationDetents([.medium, .large])
            }
            .alert("Delete Palette", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    withAnimation(.spring()) {
                        appData.palettes.removeAll(where: { $0.id == palette.id })
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \"\(livePalette.name)\"?")
            }
    }

    // MARK: - Layout

    /// The palette strip, then its colors. On iPhone Duo half open, the strip
    /// takes the side before the crease (the top, or the leading side in
    /// landscape) and the colors scroll on the other, so nothing sits on the
    /// crease.
    private var detailContent: some View {
        ZStack {
            if let fold {
                foldedContent(fold)
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        heroStrip(fillsHeight: false, stacksBands: false)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        colorGrid
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFoldChange { newFold in
            withAnimation(.smooth(duration: 0.35)) { fold = newFold }
        }
        // Folded, the strip needs the height a large title would take.
        .navigationBarTitleDisplayMode(fold == nil ? .automatic : .inline)
    }

    /// Half open, the strip fills its side and stays put while the colors
    /// scroll on the other: side by side across the top half in portrait,
    /// stacked bands down the left side in landscape.
    private func foldedContent(_ fold: Fold) -> some View {
        FoldSplit(fold: fold) {
            heroStrip(fillsHeight: true, stacksBands: fold.isVertical)
                .padding()
        } controls: {
            ScrollView {
                colorGrid
                    .padding()
            }
        }
    }

    /// Every color of the palette, with the count under it. `fillsHeight`
    /// stretches the strip to the space it's given; `stacksBands` runs the
    /// colors as horizontal bands top to bottom (a tall, narrow side) rather
    /// than side by side.
    private func heroStrip(fillsHeight: Bool, stacksBands: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = stacksBands
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(HStackLayout(spacing: 0))
            layout {
                ForEach(livePalette.paletteColors) { paletteColor in
                    Rectangle()
                        .fill(paletteColor.color)
                }
            }
            .frame(height: fillsHeight ? nil : 120)
            .frame(maxHeight: fillsHeight ? .infinity : nil)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

            Text("\(livePalette.colors.count) color\(livePalette.colors.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 4)
        }
        .matchedGeometryEffect(id: "hero", in: foldNamespace)
    }

    private var colorGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)], spacing: 20) {
            ForEach(Array(livePalette.paletteColors.enumerated()), id: \.element.id) { index, paletteColor in
                let colorVM = colorViewModel(at: index, from: livePalette)
                let role = index < livePalette.paletteColors.count ? livePalette.paletteColors[index].role : nil
                ColorCellBig(
                    colorName: colorVM.name,
                    hexCode: colorVM.HEX,
                    color: colorVM.color,
                    isUsedInPalette: true,
                    onCardTap: { editColorIndex = index }
                )
                .overlay(alignment: .topTrailing) {
                    if let role {
                        Button {
                            openTagging(for: index)
                        } label: {
                            RoleBadge(role: role)
                        }
                        .buttonStyle(.plain)
                        .padding(ColorCellBig.overlayInset)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.25), value: role)
                .matchedGeometryEffect(id: paletteColor.id, in: foldNamespace)
                // Drag to reorder within the palette; dragged out of the
                // app, it carries the hex.
                .onDrag {
                    draggedColorID = paletteColor.id
                    return NSItemProvider(object: colorVM.HEX as NSString)
                }
                .onDrop(of: [.text], delegate: ColorReorderDropDelegate(
                    targetID: paletteColor.id,
                    draggedID: $draggedColorID,
                    move: moveColor
                ))
                .contextMenu { colorContextMenu(colorVM, index: index) } preview: {
                    ColorMorphCard(
                        colorName: colorVM.name,
                        hexCode: colorVM.HEX,
                        color: colorVM.color,
                        isCompact: false
                    )
                    .frame(width: 360, height: 180)
                    .padding(4)
                    // The menu opening is the long press the onboarding hint teaches.
                    .onAppear {
                        appData.coachMarkPaletteID = nil
                        menuOpen = true
                    }
                    .onDisappear { menuOpen = false }
                }
            }
        }
    }

    // MARK: - Reordering

    /// Moves the dragged color into `targetID`'s place, the others shifting
    /// over as it passes them.
    private func moveColor(_ id: UUID, to targetID: UUID) {
        guard let paletteIdx = paletteIndex else { return }
        let colors = appData.palettes[paletteIdx].paletteColors
        guard let from = colors.firstIndex(where: { $0.id == id }),
              let to = colors.firstIndex(where: { $0.id == targetID }),
              from != to else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
            appData.palettes[paletteIdx].paletteColors.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
        reorderTick += 1
    }

    // MARK: - Color context menu

    /// Same actions as the Colors tab's card menu, minus edit/delete — those
    /// belong to the library; here the card may be a transient palette color.
    @ViewBuilder
    private func colorContextMenu(_ color: ColorViewModel, index: Int) -> some View {
        if appData.colors.contains(where: { $0.id == color.id }) {
            Button {
                toggleColorFavorite(color)
            } label: {
                Label(color.isFavorite ? "Remove Favorite" : "Favorite",
                      systemImage: color.isFavorite ? "star.slash" : "star")
            }
        }

        Button {
            openTagging(for: index)
        } label: {
            Label("Tag…", systemImage: "tag")
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
            copyToClipboard("--\(cssName): \(color.HEX);", label: "Copied CSS")
        } label: {
            Label("Export for CSS", systemImage: "curlybraces.square")
        }

        Button {
            ShareSheetPresenter.present(items: ["Check out this color: \(color.name) (\(color.HEX))"])
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private func toggleColorFavorite(_ color: ColorViewModel) {
        if let idx = appData.colors.firstIndex(where: { $0.id == color.id }) {
            appData.colors[idx].isFavorite.toggle()
        }
    }

    // MARK: - Actions

    private func openTagging(for index: Int) {
        taggingColorIndex = index
    }

    private func syncEditedPaletteColor(at index: Int, isOverwrite: Bool) {
        guard let paletteIdx = paletteIndex,
              index < appData.palettes[paletteIdx].paletteColors.count else { return }

        let updatedColor = appData.palettes[paletteIdx].paletteColors[index]

        if isOverwrite {
            if let existingIndex = appData.colors.firstIndex(where: { $0.name == updatedColor.name }) {
                appData.colors[existingIndex].HEX = updatedColor.hex
                appData.colors[existingIndex].color = updatedColor.color
            }
        } else if let existingIndex = appData.colors.firstIndex(where: {
            $0.HEX.caseInsensitiveCompare(updatedColor.hex) == .orderedSame
        }) {
            appData.colors[existingIndex].name = updatedColor.name
            appData.colors[existingIndex].color = updatedColor.color
        } else {
            appData.colors.append(
                ColorViewModel(
                    name: updatedColor.name,
                    color: updatedColor.color,
                    HEX: updatedColor.hex,
                    usedInPalette: true
                )
            )
        }
    }

    private func toggleFavorite() {
        if let idx = paletteIndex {
            appData.palettes[idx].isFavorite.toggle()
        }
    }


    // MARK: - Save as PNG

    @MainActor
    private func savePaletteAsPNG() {
        let colorVMs = livePalette.colors.indices.map { colorViewModel(at: $0, from: livePalette) }
        if let image = PaletteImageRenderer.renderImage(for: livePalette, colors: colorVMs) {
            // Passing the UIImage keeps the existing share flow and exposes iOS's
            // built-in "Save Image" action in the activity sheet.
            ShareSheetPresenter.present(items: [image])
        } else {
            ToastManager.shared.show("Unable to create PNG", icon: "exclamationmark.triangle")
        }
    }
}

#Preview {
    NavigationStack {
        PaletteDetailView(
            paletteName: "Neon Nights",
            palette: PaletteViewModel(
                name: "Neon Nights",
                colors: [.purple, .pink, .orange, .yellow, .cyan, .blue, .indigo, .black],
                hexCodes: ["#800080", "#FFC0CB", "#FFA500", "#FFFF00", "#00FFFF", "#0000FF", "#4B0082", "#000000"],
                colorNames: ["Purple", "Pink", "Orange", "Yellow", "Cyan", "Blue", "Indigo", "Black"]
            )
        )
    }
}

/// Reorders a palette's colors as one is dragged over the others. Only a
/// drag that started on one of them counts; anything else dropped here is
/// ignored.
private struct ColorReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    let move: (UUID, UUID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedID != nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedID, draggedID != targetID else { return }
        move(draggedID, targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}
