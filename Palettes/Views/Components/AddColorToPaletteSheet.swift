import SwiftUI

/// Adds colors to a saved palette (from the Edit Palette sheet). The same
/// pages as New Palette: pick several from the library, or push New Color to
/// make one in the shared editor. Either add closes the sheet.
struct AddColorToPaletteSheet: View {
    let paletteID: UUID
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case newColor
    }

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == paletteID })
    }

    private var existingHexCodes: Set<String> {
        guard let idx = paletteIndex else { return [] }
        return Set(appData.palettes[idx].hexCodes.map { $0.uppercased() })
    }

    var body: some View {
        NavigationStack(path: $path) {
            LibraryColorPicker(
                title: "Add Colors",
                excludedHexes: existingHexCodes,
                onNewColor: { path.append(.newColor) },
                onAdd: { picked in
                    add(picked.map { PaletteColor(color: $0.color, hex: $0.HEX, name: $0.name) })
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { _ in
                NewPaletteColorPage(excludedHexes: existingHexCodes) { entry in
                    add([entry])
                    dismiss()
                }
            }
        }
    }

    /// Appends the colors to the palette. The global color list is kept in
    /// sync: an existing global entry (same hex) is reused rather than
    /// duplicated.
    private func add(_ entries: [PaletteColor]) {
        guard let idx = paletteIndex else { return }

        withAnimation(.spring(response: 0.3)) {
            for entry in entries {
                guard !appData.palettes[idx].hexCodes.contains(where: {
                    $0.caseInsensitiveCompare(entry.hex) == .orderedSame
                }) else { continue }

                var entry = entry
                if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame }) {
                    entry.name = existing.name
                } else {
                    appData.colors.append(
                        ColorViewModel(name: entry.name, color: entry.color, HEX: entry.hex, usedInPalette: true)
                    )
                }
                appData.palettes[idx].paletteColors.append(entry)
            }
        }
    }
}
