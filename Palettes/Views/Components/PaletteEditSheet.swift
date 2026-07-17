import SwiftUI

// MARK: - Palette Edit Sheet 

struct PaletteEditSheet: View {
    let paletteName: String
    let palette: PaletteViewModel
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    @State private var isAddingColor = false
    @State private var editColorIndex: Int?

    struct ColorBindingWrapper: Identifiable {
        let id: Int
    }

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == palette.id })
    }
    
    private var paletteNameBinding: Binding<String> {
        Binding(
            get: {
                if let idx = paletteIndex { return appData.palettes[idx].name }
                return paletteName
            },
            set: { newValue in
                if let idx = paletteIndex {
                    appData.palettes[idx].name = newValue
                }
            }
        )
    }

    private var livePalette: PaletteViewModel {
        if let idx = paletteIndex { return appData.palettes[idx] }
        return palette
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Palette Name", text: paletteNameBinding)
                        .font(.system(size: 18, weight: .medium))
                }
                
                Section(footer: Text("Tap a color to edit it. Swipe left to delete.")) {
                    ForEach(Array(livePalette.colors.enumerated()), id: \.offset) { index, _ in
                        let colorVM = colorViewModel(at: index, from: livePalette)
                        Button {
                            editColorIndex = index
                        } label: {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(colorVM.color.gradient)
                                    .frame(width: 50, height: 50)
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                                    .shadow(color: colorVM.color.opacity(0.3), radius: 5, x: 0, y: 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(colorVM.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    HStack(spacing: 6) {
                                        Text(colorVM.HEX)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        Text(colorVM.color.rgbString)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        removeColors(at: offsets)
                    }
                }
            }
            .listStyle(.insetGrouped)
            // Sheets cover the app-root toast overlay, so host one here too.
            .toastOverlay()
            .navigationTitle("Edit Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingColor = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .glassButton(prominent: true)
                    .tint(.accentColor)
                }
            }
            .sheet(isPresented: $isAddingColor) {
                AddColorToPaletteSheet(paletteID: palette.id)
                    .environmentObject(appData)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: Binding(
                get: {
                    if let idx = editColorIndex, idx < livePalette.colors.count {
                        return ColorBindingWrapper(id: idx)
                    }
                    return nil
                },
                set: { newValue in
                    if newValue == nil {
                        editColorIndex = nil
                    }
                }
            )) { wrapper in
                if let paletteIdx = paletteIndex {
                    ColorEditView(
                        colorName: $appData.palettes[paletteIdx].paletteColors[wrapper.id].name,
                        hexCode: $appData.palettes[paletteIdx].paletteColors[wrapper.id].hex,
                        colorValue: $appData.palettes[paletteIdx].paletteColors[wrapper.id].color,
                        promptOnNameMatch: true,
                        onSaveWithAction: { isOverwrite in
                            let updatedHex = appData.palettes[paletteIdx].paletteColors[wrapper.id].hex
                            let updatedName = appData.palettes[paletteIdx].paletteColors[wrapper.id].name
                            let updatedColor = appData.palettes[paletteIdx].paletteColors[wrapper.id].color
                            
                            if isOverwrite {
                                if let existingIndex = appData.colors.firstIndex(where: { $0.name == updatedName }) {
                                    appData.colors[existingIndex].HEX = updatedHex
                                    appData.colors[existingIndex].color = updatedColor
                                }
                            } else {
                                if let existingIndex = appData.colors.firstIndex(where: { $0.HEX.caseInsensitiveCompare(updatedHex) == .orderedSame }) {
                                    appData.colors[existingIndex].name = updatedName
                                    appData.colors[existingIndex].color = updatedColor
                                } else {
                                    appData.colors.append(ColorViewModel(name: updatedName, color: updatedColor, HEX: updatedHex, usedInPalette: true))
                                }
                            }
                        }
                    )
                    .environmentObject(appData)
                    .presentationDetents([.large])
                }
            }
        }
    }

    private func removeColors(at offsets: IndexSet) {
        guard let idx = paletteIndex else { return }
        let paletteID = palette.id
        // Capture each removed entry (ascending indices) so Undo can reinsert
        // them at their original spots.
        let removed: [(index: Int, entry: PaletteColor)] = offsets.sorted().map { i in
            (i, appData.palettes[idx].paletteColors[i])
        }
        appData.palettes[idx].paletteColors.remove(atOffsets: offsets)

        let count = removed.count
        ToastManager.shared.show(count == 1 ? "Color removed" : "\(count) colors removed", icon: "trash.fill") { [weak appData] in
            guard let appData,
                  let idx = appData.palettes.firstIndex(where: { $0.id == paletteID }) else { return }
            withAnimation(.spring()) {
                for (index, entry) in removed {
                    appData.palettes[idx].paletteColors.insert(entry, at: min(index, appData.palettes[idx].paletteColors.count))
                }
            }
        }
    }

    private func colorViewModel(at index: Int, from pal: PaletteViewModel) -> ColorViewModel {
        let hex = index < pal.hexCodes.count ? pal.hexCodes[index] : ""
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            return existing
        }
        let name = index < pal.colorNames.count ? pal.colorNames[index] : "Color \(index + 1)"
        return ColorViewModel(name: name, color: pal.colors[index], HEX: hex, usedInPalette: true)
    }
}
