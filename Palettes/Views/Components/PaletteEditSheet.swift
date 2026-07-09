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
                    .buttonStyle(.glassProminent)
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
                        colorName: $appData.palettes[paletteIdx].colorNames[wrapper.id],
                        hexCode: $appData.palettes[paletteIdx].hexCodes[wrapper.id],
                        colorValue: $appData.palettes[paletteIdx].colors[wrapper.id],
                        promptOnNameMatch: true,
                        onSaveWithAction: { isOverwrite in
                            let updatedHex = appData.palettes[paletteIdx].hexCodes[wrapper.id]
                            let updatedName = appData.palettes[paletteIdx].colorNames[wrapper.id]
                            let updatedColor = appData.palettes[paletteIdx].colors[wrapper.id]
                            
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
        appData.palettes[idx].colors.remove(atOffsets: offsets)
        let hexValid = offsets.filter { $0 < appData.palettes[idx].hexCodes.count }
        appData.palettes[idx].hexCodes.remove(atOffsets: IndexSet(hexValid))
        let nameValid = offsets.filter { $0 < appData.palettes[idx].colorNames.count }
        appData.palettes[idx].colorNames.remove(atOffsets: IndexSet(nameValid))
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
