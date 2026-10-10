import SwiftUI
import PhotosUI

/// "New Palette" sheet. One sheet, no sheets on top of it: the palette and
/// its name stay pinned at the top, the colors are a standard list below
/// (tap to edit, swipe to remove, touch and hold to reorder), and adding a
/// color pushes a page — a new color in the shared editor, or several from the
/// library — or pulls a whole palette from a photo. Nothing is saved until
/// Create, and an unsaved palette asks before it's thrown away.
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
    @State private var path: [Route] = []
    @FocusState private var nameFocused: Bool

    private enum Route: Hashable {
        case newColor
        case library
        case edit(UUID)
    }

    // Photo
    @State private var showPhotoLibrary = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCameraCapture = false
    @State private var pendingScan: [PaletteColor] = []
    @State private var showScanChoice = false

    @State private var showDiscardConfirmation = false
    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false
    @State private var duplicateOfName = ""

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    private var canCreate: Bool { draft.count >= 2 }

    private var hasChanges: Bool {
        !draft.isEmpty || !paletteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var draftHexes: Set<String> {
        Set(draft.map { $0.hex.uppercased() })
    }

    private var nameHint: String {
        suggestedName.isEmpty ? "Names the palette" : "Leave blank to use \(suggestedName)"
    }

    private var resolvedName: String {
        let typed = paletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return suggestedName.isEmpty ? "Untitled Palette" : suggestedName
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header

                List {
                    if !draft.isEmpty {
                        colorsSection
                    }
                    addSection
                }
                .scrollDismissesKeyboard(.interactively)
                .animation(.spring(duration: 0.35, bounce: 0), value: draft.map(\.id))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { cancel() }
                        .confirmationDialog(
                            "Discard this palette?",
                            isPresented: $showDiscardConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Discard Palette", role: .destructive) { dismiss() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(title: "Create") { createPalette() }
                        .disabled(!canCreate)
                }
            }
            .navigationDestination(for: Route.self) { route in
                destination(for: route)
            }
            .confirmationDialog(
                "Use the colors from this photo?",
                isPresented: $showScanChoice,
                titleVisibility: .visible
            ) {
                Button("Add \(pendingScan.count) Colors") { applyScan(.append) }
                Button("Replace Current Colors", role: .destructive) { applyScan(.replace) }
                Button("Cancel", role: .cancel) { pendingScan = [] }
            } message: {
                Text("Add them to the colors already in this palette, or start over with just these.")
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
            .photosPicker(isPresented: $showPhotoLibrary, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                if let image = cameraImage {
                    cameraImage = nil
                    useColors(from: image)
                }
            }) {
                CameraPicker(image: $cameraImage, didCapture: $didCameraCapture, isPresented: $showCamera)
            }
        }
        // Sheets cover the app-root toast overlay, so host one here too.
        .toastOverlay()
        // A swipe down mustn't silently throw away colors; Cancel asks first.
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            guard !didSeedPreselected else { return }
            didSeedPreselected = true
            if let color = preselectedColor {
                draft.append(PaletteColor(color: color.color, hex: color.HEX, name: color.name))
            }
        }
        .onChange(of: draft.map(\.hex)) { _, hexes in
            updateSuggestedName(for: hexes)
        }
    }

    // MARK: - Header

    /// The palette as it will look, and its name. Pinned, so it stays in view
    /// while the list scrolls.
    private var header: some View {
        VStack(spacing: 12) {
            PaletteStrip(colors: draft.map(\.color), height: 88, cornerRadius: 22)
                .overlay {
                    if draft.isEmpty {
                        Text("Your palette will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .shadow(color: .black.opacity(draft.isEmpty ? 0 : 0.1), radius: 10, x: 0, y: 5)

            TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $paletteName)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .focused($nameFocused)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Palette name")
                .accessibilityHint(nameHint)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Sections

    private var colorsSection: some View {
        Section {
            ForEach(draft) { entry in
                NavigationLink(value: Route.edit(entry.id)) {
                    ColorRowLabel(color: entry.color, name: entry.name, hex: entry.hex)
                }
            }
            .onDelete { offsets in
                draft.remove(atOffsets: offsets)
            }
            .onMove { offsets, destination in
                draft.move(fromOffsets: offsets, toOffset: destination)
            }
        } header: {
            Text(draft.count == 1 ? "1 Color" : "\(draft.count) Colors")
        } footer: {
            Text("Tap a color to edit it. Touch and hold to reorder, or swipe left to remove.")
        }
    }

    private var addSection: some View {
        Section {
            NavigationLink(value: Route.newColor) {
                Label("New Color", systemImage: "plus.circle.fill")
            }

            if !appData.colors.isEmpty {
                NavigationLink(value: Route.library) {
                    Label("From Your Library", systemImage: "square.grid.2x2.fill")
                }
            }

            if Self.cameraAvailable {
                Menu {
                    Button("Choose Photo", systemImage: "photo.on.rectangle") { showPhotoLibrary = true }
                    Button("Take Photo", systemImage: "camera") { showCamera = true }
                } label: {
                    Label("From a Photo", systemImage: "photo.fill")
                }
            } else {
                Button {
                    showPhotoLibrary = true
                } label: {
                    Label("From a Photo", systemImage: "photo.fill")
                }
            }
        } header: {
            Text(draft.isEmpty ? "Add Colors" : "Add More")
        } footer: {
            switch draft.count {
            case 0:
                Text("A palette needs at least two colors. Add them one at a time, or pull a whole palette from a photo.")
            case 1:
                Text("Add one more color to create the palette.")
            default:
                EmptyView()
            }
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .newColor:
            NewPaletteColorPage(excludedHexes: draftHexes) { entry in
                append([entry])
            }
        case .library:
            LibraryColorPicker(excludedHexes: draftHexes) { picked in
                append(picked.map { PaletteColor(color: $0.color, hex: $0.HEX, name: $0.name) })
            }
        case .edit(let id):
            // Edits apply live; Back is all it takes.
            ColorComposer(color: colorBinding(for: id), name: nameBinding(for: id))
                .navigationTitle("Edit Color")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// Edits the color and keeps its hex in step.
    private func colorBinding(for id: UUID) -> Binding<Color> {
        Binding(
            get: { draft.first(where: { $0.id == id })?.color ?? .gray },
            set: { newColor in
                guard let index = draft.firstIndex(where: { $0.id == id }) else { return }
                draft[index].color = newColor
                draft[index].hex = ColorComposer.hexKey(newColor)
            }
        )
    }

    private func nameBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { draft.first(where: { $0.id == id })?.name ?? "" },
            set: { newName in
                guard let index = draft.firstIndex(where: { $0.id == id }) else { return }
                draft[index].name = newName
            }
        )
    }

    // MARK: - Draft

    private func append(_ colors: [PaletteColor]) {
        var seen = draftHexes
        for color in colors where !seen.contains(color.hex.uppercased()) {
            seen.insert(color.hex.uppercased())
            draft.append(color)
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            photoItem = nil   // so the same photo can be chosen again
            guard let data, let image = UIImage(data: data) else {
                ToastManager.shared.show("Couldn't open that photo", icon: "exclamationmark.triangle.fill")
                return
            }
            // Let the photo picker finish dismissing before asking anything.
            try? await Task.sleep(for: .milliseconds(300))
            useColors(from: image)
        }
    }

    /// Pulls a palette from the photo. An empty draft takes it as is; a draft
    /// with colors asks whether to add to them or start over.
    private func useColors(from image: UIImage) {
        do {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 6)
            let colors = extracted.compactMap { item -> PaletteColor? in
                guard let color = Color(hex: item.hex) else { return nil }
                return PaletteColor(color: color, hex: item.hex, name: item.name)
            }
            guard !colors.isEmpty else { return }
            if draft.isEmpty {
                draft = colors
            } else {
                pendingScan = colors
                showScanChoice = true
            }
        } catch {
            ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
        }
    }

    private enum ScanMergeMode {
        case replace, append
    }

    private func applyScan(_ mode: ScanMergeMode) {
        switch mode {
        case .replace: draft = pendingScan
        case .append: append(pendingScan)
        }
        pendingScan = []
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

    private func cancel() {
        if hasChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
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
        let colors = draft.map { entry -> PaletteColor in
            var entry = entry
            let trimmed = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.name = trimmed.isEmpty ? ColorNamer.name(forHex: entry.hex) : trimmed
            return entry
        }
        let newPalette = PaletteViewModel(name: resolvedName, paletteColors: colors)
        withAnimation {
            appData.palettes.append(newPalette)

            for entry in colors where !entry.hex.isEmpty {
                let alreadyExists = appData.colors.contains {
                    $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame
                }
                if !alreadyExists {
                    appData.colors.append(ColorViewModel(
                        name: entry.name,
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

/// A color in a list: rounded swatch, name, and hex.
struct ColorRowLabel: View {
    let color: Color
    let name: String
    let hex: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Untitled" : name)
                    .lineLimit(1)
                Text(hex)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    NewPaletteView()
        .environmentObject(AppData(inMemory: true))
}
