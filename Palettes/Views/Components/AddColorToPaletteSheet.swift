import SwiftUI

/// The shared "Add Colors" sheet: a live strip of the palette on top, so each
/// color can be seen landing, and the `ColorInputView` engine below. It stays
/// open for several adds; a photo scan that yields a whole palette closes it
/// (asking first whether to add to or replace colors already there).
struct AddColorsSheet: View {
    let paletteColors: [Color]
    var sources: [ColorInputSource] = [.library, .pick, .scan]
    var initialSource: ColorInputSource? = nil
    var scanExtraction: ScanExtraction = .dominant
    var excludedHexes: Set<String> = []
    var onAdd: (ColorInputEntry) -> Void
    var onScanPalette: (([ColorInputEntry], ScanMergeMode) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appData: AppData

    @State private var pendingScan: [ColorInputEntry] = []
    @State private var showScanChoice = false

    private var countCaption: String {
        switch paletteColors.count {
        case 0: return "Add at least two colors"
        case 1: return "1 color · add one more"
        default: return "\(paletteColors.count) colors"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        PaletteStrip(colors: paletteColors, height: 44, cornerRadius: 14)
                        Text(countCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: paletteColors.count)
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    ColorInputView(
                        sources: sources,
                        initialSource: initialSource,
                        scanExtraction: scanExtraction,
                        excludedHexes: excludedHexes,
                        addButtonTitle: "Add to Palette",
                        onAdd: onAdd,
                        onScanPalette: { entries in handleScan(entries) }
                    )
                    .environmentObject(appData)
                }
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Colors")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Use the colors from this photo?",
                isPresented: $showScanChoice,
                titleVisibility: .visible
            ) {
                Button("Add \(pendingScan.count) Colors") { finishScan(.append) }
                Button("Replace Current Colors", role: .destructive) { finishScan(.replace) }
                Button("Cancel", role: .cancel) { pendingScan = [] }
            } message: {
                Text("Add them to the colors already in this palette, or start over with just these.")
            }
        }
    }

    private func handleScan(_ entries: [ColorInputEntry]) {
        guard !entries.isEmpty else { return }
        if paletteColors.isEmpty {
            onScanPalette?(entries, .replace)
            dismiss()
        } else {
            pendingScan = entries
            showScanChoice = true
        }
    }

    private func finishScan(_ mode: ScanMergeMode) {
        onScanPalette?(pendingScan, mode)
        pendingScan = []
        dismiss()
    }
}

/// Adds colors straight into a saved palette (from the Edit Palette sheet).
struct AddColorToPaletteSheet: View {
    let paletteID: UUID
    @EnvironmentObject var appData: AppData

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == paletteID })
    }

    private var existingHexCodes: Set<String> {
        guard let idx = paletteIndex else { return [] }
        return Set(appData.palettes[idx].hexCodes.map { $0.uppercased() })
    }

    var body: some View {
        AddColorsSheet(
            paletteColors: paletteIndex.map { appData.palettes[$0].colors } ?? [],
            sources: [.library, .pick, .scan],
            scanExtraction: .dominant,
            excludedHexes: existingHexCodes,
            onAdd: { entry in add(entry) }
        )
        .environmentObject(appData)
    }

    /// Appends the color to the palette; the sheet stays open so several
    /// colors can be added in one visit, and the strip on top shows each one
    /// arrive. Global color list is kept in sync: an existing global entry
    /// (same hex) is reused rather than duplicated.
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
    }
}
