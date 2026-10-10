import SwiftUI

/// "New Palette" sheet, laid out like the Generate result so a hand-made
/// palette looks the way it will once saved while it's being shaped: the name
/// on top, one card with a band per color, and an Add Colors action that opens
/// the shared color input over it. Nothing is saved until Create.
struct NewPaletteView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    var preselectedColor: ColorViewModel? = nil

    @State private var paletteName = ""
    /// The draft, one entry per color — name, hex and color always together.
    @State private var draft: [PaletteColor] = []
    /// Used when the name is left blank; recomputed as the colors change.
    @State private var suggestedName = ""
    @State private var didSeedPreselected = false

    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?

    private struct AddTarget: Identifiable {
        let source: ColorInputSource
        var id: String { source.rawValue }
    }
    @State private var addTarget: AddTarget?

    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false
    @State private var duplicateOfName = ""

    private var canCreate: Bool { draft.count >= 2 }

    private var draftHexes: Set<String> {
        Set(draft.map { $0.hex.uppercased() })
    }

    private var resolvedName: String {
        let typed = paletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return suggestedName.isEmpty ? "Untitled Palette" : suggestedName
    }

    private var sources: [ColorInputSource] {
        appData.colors.isEmpty ? [.pick, .scan] : [.library, .pick, .scan]
    }

    private var nameHint: String {
        suggestedName.isEmpty ? "Names the palette" : "Leave blank to use the suggestion, \(suggestedName)"
    }

    private var statusCaption: String {
        switch draft.count {
        case 0: return "Add at least two colors to get started"
        case 1: return "1 color · add one more"
        default: return "\(draft.count) colors · Tap a color to edit"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    nameHeader

                    if draft.isEmpty {
                        startCard
                            .transition(.opacity)
                    } else {
                        PaletteBandCard(
                            colors: draft,
                            onEdit: { editTarget = EditTarget(id: $0) },
                            onRemove: { removeColor(at: $0) },
                            onMove: { from, to in moveColor(from: from, to: to) }
                        )

                        Button {
                            openAdd(sources.first ?? .pick)
                        } label: {
                            Label("Add Colors", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .glassButton()
                        .tint(.primary)
                    }
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: draft.isEmpty)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New Palette")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createPalette() }
                        .glassButton(prominent: true)
                        .fontWeight(.semibold)
                        .disabled(!canCreate)
                }
            }
            // Sheets cover the app-root toast overlay, so host one here too.
            .toastOverlay()
            .sheet(item: $addTarget) { target in
                AddColorsSheet(
                    paletteColors: draft.map(\.color),
                    sources: sources,
                    initialSource: target.source,
                    scanExtraction: .palette(count: 6),
                    excludedHexes: draftHexes,
                    onAdd: { entry in appendToDraft(entry) },
                    onScanPalette: { entries, mode in applyScan(entries, mode: mode) }
                )
                .environmentObject(appData)
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $editTarget) { target in
                if target.id < draft.count {
                    ColorEditView(
                        colorName: $draft[target.id].name,
                        hexCode: $draft[target.id].hex,
                        colorValue: $draft[target.id].color
                    )
                    .environmentObject(appData)
                    .presentationDetents([.large])
                }
            }
            .alert("Palette Already Exists", isPresented: $showDuplicateAlert) {
                Button("Save Anyway") { performCreate() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A palette with these colors already exists as \"\(duplicateOfName)\".")
            }
            .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                Button("Save Anyway") { performCreate() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A palette named \"\(duplicateOfName)\" already exists.")
            }
            .onAppear {
                guard !didSeedPreselected else { return }
                didSeedPreselected = true
                if let color = preselectedColor {
                    appendToDraft(ColorInputEntry(name: color.name, hex: color.HEX, color: color.color))
                }
            }
            .onChange(of: draft.map(\.hex)) { _, hexes in
                updateSuggestedName(for: hexes)
            }
        }
    }

    // MARK: - Name

    /// Big rounded name, as on the Generate result. Left blank, the palette
    /// takes the suggestion shown as the placeholder.
    private var nameHeader: some View {
        VStack(spacing: 6) {
            TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $paletteName)
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .accessibilityLabel("Palette name")
                .accessibilityHint(nameHint)

            Text(statusCaption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: draft.count)
        }
    }

    // MARK: - Empty State

    /// Before the first color: where the card will be, with the three ways to
    /// start right on it.
    private var startCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(systemName: "swatchpalette")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Start with a color")
                    .font(.headline)
                Text(appData.colors.isEmpty
                     ? "Pick one, or pull a whole palette from a photo."
                     : "Pick one, choose from your library, or pull a whole palette from a photo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                startButton("Pick", systemImage: "eyedropper", source: .pick)
                if !appData.colors.isEmpty {
                    startButton("Library", systemImage: "circle.grid.cross", source: .library)
                }
                startButton("Photo", systemImage: "camera", source: .scan)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
        )
    }

    private func startButton(_ title: String, systemImage: String, source: ColorInputSource) -> some View {
        Button {
            openAdd(source)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .liquidGlass(.interactive, in: .rect(cornerRadius: 18))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Draft

    private func openAdd(_ source: ColorInputSource) {
        addTarget = AddTarget(source: source)
    }

    private func appendToDraft(_ entry: ColorInputEntry) {
        guard !draftHexes.contains(entry.hex.uppercased()) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            draft.append(PaletteColor(color: entry.color, hex: entry.hex, name: entry.name))
        }
    }

    private func applyScan(_ entries: [ColorInputEntry], mode: ScanMergeMode) {
        let incoming = entries.map { PaletteColor(color: $0.color, hex: $0.hex, name: $0.name) }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            switch mode {
            case .replace:
                draft = incoming
            case .append:
                var seen = draftHexes
                for color in incoming where !seen.contains(color.hex.uppercased()) {
                    seen.insert(color.hex.uppercased())
                    draft.append(color)
                }
            }
        }
    }

    private func removeColor(at index: Int) {
        guard index < draft.count else { return }
        _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            draft.remove(at: index)
        }
    }

    private func moveColor(from: Int, to: Int) {
        guard draft.indices.contains(from), draft.indices.contains(to) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            draft.swapAt(from, to)
        }
    }

    private func updateSuggestedName(for hexes: [String]) {
        guard hexes.count >= 2 else {
            suggestedName = ""
            return
        }
        suggestedName = PaletteNamer.descriptiveName(
            forHexes: hexes,
            existingNames: appData.palettes.map(\.name)
        )
    }

    // MARK: - Create

    private func createPalette() {
        guard canCreate else { return }

        if let existing = appData.existingPalette(matching: draft.map(\.hex)) {
            duplicateOfName = existing.name
            showDuplicateAlert = true
            return
        }
        if let existing = appData.existingPalette(named: resolvedName) {
            duplicateOfName = existing.name
            showNameDuplicateAlert = true
            return
        }
        performCreate()
    }

    private func performCreate() {
        let newPalette = PaletteViewModel(name: resolvedName, paletteColors: draft)
        withAnimation {
            appData.palettes.append(newPalette)

            for entry in draft where !entry.hex.isEmpty {
                let alreadyExists = appData.colors.contains {
                    $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame
                }
                if !alreadyExists {
                    appData.colors.append(ColorViewModel(
                        name: entry.name.isEmpty ? "Untitled" : entry.name,
                        color: entry.color,
                        HEX: entry.hex,
                        usedInPalette: true
                    ))
                }
            }
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NewPaletteView()
        .environmentObject(AppData(inMemory: true))
}
