import SwiftUI

// MARK: - Palette Edit Sheet

/// "Edit Palette" sheet: the shared `PaletteEditor` on a draft of the palette.
/// Cancel throws the changes away; ✓ writes name and colors back in one go.
struct PaletteEditSheet: View {
    let paletteName: String
    let palette: PaletteViewModel
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    private var livePalette: PaletteViewModel {
        appData.palettes.first(where: { $0.id == palette.id }) ?? palette
    }

    var body: some View {
        PaletteEditor(
            mode: .edit(paletteID: palette.id),
            draft: PaletteDraft(palette: livePalette),
            onConfirm: save
        )
    }

    private func save(_ draft: PaletteDraft, name: String) {
        guard draft.canSave else { return }
        let colors = draft.finalizedColors()
        if let index = appData.palettes.firstIndex(where: { $0.id == palette.id }) {
            var updated = appData.palettes[index]
            updated.name = name
            updated.paletteColors = colors
            withAnimation {
                appData.palettes[index] = updated
                // Q17: the palette's colors are its own; hexes the library
                // doesn't know yet join it, existing library colors never change.
                appData.addPaletteColorsToLibrary(colors, isGenerated: false)
            }
        }
        dismiss()
    }
}
