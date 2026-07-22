import SwiftUI

struct AddColorToPaletteSheet: View {
    let paletteID: UUID
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == paletteID })
    }

    private var existingHexCodes: Set<String> {
        guard let idx = paletteIndex else { return [] }
        return Set(appData.palettes[idx].hexCodes.map { $0.uppercased() })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ColorInputView(
                    sources: [.library, .pick, .scan],
                    scanExtraction: .dominant,
                    excludedHexes: existingHexCodes,
                    addButtonTitle: "Add to Palette",
                    onAdd: { entry in
                        add(entry)
                    }
                )
                .environmentObject(appData)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Color")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    /// Appends the color to the palette and keeps the sheet open so several
    /// colors can be added in one visit. Global color list is kept in sync:
    /// an existing global entry (same hex) is reused rather than duplicated.
    private func add(_ entry: ColorInputEntry) {
        guard let idx = paletteIndex else { return }

        var name = entry.name
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame }) {
            name = existing.name
        }

        withAnimation(.spring(response: 0.3)) {
            appData.palettes[idx].paletteColors.append(
                PaletteColor(color: entry.color, hex: entry.hex, name: name)
            )

            let alreadyExists = appData.colors.contains {
                $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame
            }
            if !alreadyExists {
                appData.colors.append(
                    ColorViewModel(name: name, color: entry.color, HEX: entry.hex, usedInPalette: true)
                )
            }
        }
        ToastManager.shared.show("Added \(name)", icon: "checkmark.circle.fill")
    }
}
