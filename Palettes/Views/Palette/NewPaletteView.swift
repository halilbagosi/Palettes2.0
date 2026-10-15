import SwiftUI

/// "New Palette" sheet: the shared `PaletteEditor` on an empty draft (or one
/// seeded with `preselectedColor`). Create checks for an existing palette with
/// the same colors or name before saving.
struct NewPaletteView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    var preselectedColor: ColorViewModel? = nil

    @State private var pending: (draft: PaletteDraft, name: String)?
    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false
    @State private var duplicateOfName = ""

    private var seed: PaletteDraft {
        PaletteDraft(colors: preselectedColor.map {
            [PaletteColor(color: $0.color, hex: $0.HEX, name: $0.name)]
        } ?? [])
    }

    var body: some View {
        PaletteEditor(mode: .create, draft: seed, onConfirm: create)
            .alert("Palette Already Exists", isPresented: $showDuplicateAlert) {
                Button("Save Anyway") { performCreate() }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: {
                Text("A palette with these colors already exists as \"\(duplicateOfName)\".")
            }
            .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                Button("Save Anyway") { performCreate() }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: {
                Text("A palette named \"\(duplicateOfName)\" already exists.")
            }
    }

    private func create(_ draft: PaletteDraft, name: String) {
        guard draft.canSave else { return }
        pending = (draft, name)

        if let existing = appData.existingPalette(matching: draft.colors.map(\.hex)) {
            duplicateOfName = existing.name
            showDuplicateAlert = true
            return
        }
        if let existing = appData.existingPalette(named: name) {
            duplicateOfName = existing.name
            showNameDuplicateAlert = true
            return
        }
        performCreate()
    }

    private func performCreate() {
        guard let (draft, name) = pending else { return }
        let colors = draft.finalizedColors()
        withAnimation {
            appData.palettes.append(PaletteViewModel(name: name, paletteColors: colors))
            appData.addPaletteColorsToLibrary(colors, isGenerated: false)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NewPaletteView()
        .environmentObject(AppData(inMemory: true))
}
