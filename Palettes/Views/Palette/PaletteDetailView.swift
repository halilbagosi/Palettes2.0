//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 14.2.26.
//
import SwiftUI
import PhotosUI



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
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Hero Palette Strip
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(livePalette.colors.indices, id: \.self) { index in
                            Rectangle()
                                .fill(livePalette.colors[index])
                        }
                    }
                    .frame(height: 120)
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
                .padding(.horizontal)
                .padding(.top, 8)

                // MARK: Color Cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)], spacing: 20) {
                    ForEach(Array(livePalette.colors.enumerated()), id: \.offset) { index, _ in
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
                        .draggable(colorVM.HEX)
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
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(livePalette.name)
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
