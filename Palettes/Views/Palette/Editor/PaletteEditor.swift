//
//  PaletteEditor.swift
//  Palettes
//
//  The one palette editor, for New Palette and Edit Palette. It works on a
//  `PaletteDraft`: the palette strip is pinned at the top (tap a band to edit
//  it, hold to reorder, + to add), the name sits under it, and an empty
//  palette offers ways to start instead of a list. Nothing reaches AppData
//  until ✓; the wrapper that presents the editor decides what ✓ does.
//

import SwiftUI
import PhotosUI

enum PaletteEditorRoute: Hashable {
    case newColor
    case library
    case edit(UUID)
    case tag(UUID)
    case harmony(base: String?)
    case photo
}

struct PaletteEditor: View {
    enum Mode: Equatable {
        case create
        case edit(paletteID: UUID)
    }

    let mode: Mode
    /// Called with the draft and the name to save it under (the typed name,
    /// else the suggestion). The presenter validates, saves and dismisses.
    var onConfirm: (PaletteDraft, _ resolvedName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appData: AppData

    @State private var draft: PaletteDraft
    /// What the editor opened with, to tell whether anything changed.
    @State private var original: PaletteDraft
    @State private var selection: UUID?
    @State private var path: [PaletteEditorRoute] = []
    /// Used when the name is left blank; recomputed as the colors change.
    @State private var suggestedName = ""
    @State private var showDiscardConfirmation = false
    /// Generate asked to leave with unsaved changes; once they're discarded,
    /// go on to the Generate tab.
    @State private var generateAfterDiscard = false
    @FocusState private var nameFocused: Bool

    // Photo
    @State private var showPhotoLibrary = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCameraCapture = false
    /// The photo being turned into colors on the From a Photo page.
    @State private var photoImage: UIImage?

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    init(mode: Mode, draft: PaletteDraft, onConfirm: @escaping (PaletteDraft, String) -> Void) {
        self.mode = mode
        self.onConfirm = onConfirm
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    private var isCreating: Bool { mode == .create }
    private var hasChanges: Bool { draft != original }

    private var nameHint: String {
        suggestedName.isEmpty ? "Names the palette" : "Leave blank to use \(suggestedName)"
    }

    /// Generate is a tab, and only some devices have it. It starts a new
    /// palette, so it has no place when editing one.
    private var showsGenerate: Bool { isCreating && AppleIntelligence.isDeviceSupported }

    private var appendAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header

                List {
                    if draft.colors.isEmpty {
                        startSection
                    } else {
                        hintSection
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isCreating ? "New Palette" : "Edit Palette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { cancel() }
                        .confirmationDialog(
                            isCreating ? "Discard this palette?" : "Discard changes?",
                            isPresented: $showDiscardConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button(isCreating ? "Discard Palette" : "Discard Changes", role: .destructive) {
                                ToastManager.shared.dismissUndo()
                                if generateAfterDiscard { appData.activeTab = .generate }
                                dismiss()
                            }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(kind: isCreating ? .create : .save) { confirm() }
                        .disabled(!draft.canSave)
                }
            }
            .navigationDestination(for: PaletteEditorRoute.self) { route in
                destination(for: route)
            }
            .photosPicker(isPresented: $showPhotoLibrary, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                if let image = cameraImage {
                    cameraImage = nil
                    showPhotoPins(for: image)
                }
            }) {
                CameraPicker(image: $cameraImage, didCapture: $didCameraCapture, isPresented: $showCamera)
            }
        }
        // Sheets cover the app-root toast overlay, so host one here too.
        .toastOverlay()
        // A swipe down mustn't silently throw away changes; Cancel asks first.
        .interactiveDismissDisabled(hasChanges)
        .onAppear { updateSuggestedName() }
        // A pending Undo mustn't outlive the draft it would act on.
        .onDisappear { ToastManager.shared.dismissUndo() }
        .onChange(of: draft.colors.map(\.hex)) { _, _ in
            updateSuggestedName()
        }
    }

    // MARK: - Header

    /// The palette as it will look, and its name. Pinned, so it stays in view
    /// while the list scrolls.
    private var header: some View {
        VStack(spacing: 12) {
            if draft.colors.isEmpty {
                emptyStrip
            } else {
                PaletteStripEditor(
                    draft: $draft,
                    selection: $selection,
                    onEdit: { path.append(.edit($0)) },
                    onTag: { path.append(.tag($0)) },
                    addMenu: AnyView(addMenuContent),
                    onRemove: { index, color in removed(color, at: index) }
                )
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }

            TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $draft.name)
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

    private var emptyStrip: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .overlay {
                Text("Your palette will appear here")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Empty palette")
    }

    // MARK: - List

    private var startSection: some View {
        Section {
            PaletteStartTiles(
                showsLibrary: !appData.colors.isEmpty,
                showsGenerate: showsGenerate,
                cameraAvailable: Self.cameraAvailable,
                onChoosePhoto: { showPhotoLibrary = true },
                onTakePhoto: { showCamera = true },
                onLibrary: { path.append(.library) },
                onOneColor: { path.append(.harmony(base: nil)) },
                onGenerate: generate,
                onStartBlank: { path.append(.newColor) }
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }
    }

    /// Footer-style guidance under the strip, in a clear row so it shows
    /// whatever the list has to say.
    private var hintSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tap a color to edit it. Touch and hold to move it.")
                if draft.colors.count == 1 {
                    Text("Add one more color to create the palette.")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        }
    }

    // MARK: - + menu

    private var harmonyBase: String? {
        if let selection, let hex = draft.colors.first(where: { $0.id == selection })?.hex {
            return hex
        }
        return draft.colors.last?.hex
    }

    @ViewBuilder
    private var addMenuContent: some View {
        Button { path.append(.newColor) } label: {
            Label("New Color", systemImage: "plus.circle")
        }

        if !appData.colors.isEmpty {
            Button { path.append(.library) } label: {
                Label("From My Colors", systemImage: "square.grid.2x2")
            }
        }

        if Self.cameraAvailable {
            Menu {
                Button("Choose Photo", systemImage: "photo.on.rectangle") { showPhotoLibrary = true }
                Button("Take Photo", systemImage: "camera") { showCamera = true }
            } label: {
                Label("From a Photo", systemImage: "photo")
            }
        } else {
            Button { showPhotoLibrary = true } label: {
                Label("From a Photo", systemImage: "photo")
            }
        }

        Button { path.append(.harmony(base: harmonyBase)) } label: {
            Label("Colors That Go With…", systemImage: "paintpalette")
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func destination(for route: PaletteEditorRoute) -> some View {
        switch route {
        case .newColor:
            NewPaletteColorPage(excludedHexes: draft.hexes) { entry in
                append([entry])
            }
        case .library:
            LibraryColorPicker(excludedHexes: draft.hexes, onAdd: { picked in
                append(picked.map { PaletteColor(color: $0.color, hex: $0.HEX, name: $0.name) })
            })
        case .edit(let id):
            EditColorPage(draft: $draft, id: id) { path.append(.tag(id)) }
        case .tag(let id):
            RoleList(
                current: draft.colors.first(where: { $0.id == id })?.role,
                onSelect: { role in
                    draft.setRole(role, for: id)
                    if !path.isEmpty { path.removeLast() }
                },
                onTagRenamed: { old, new in
                    // The tag is renamed app-wide, saved palettes included;
                    // the draft (and what it's compared with) follows.
                    draft.renameRole(old, to: new)
                    original.renameRole(old, to: new)
                },
                onTagDeleted: { name in
                    draft.clearRole(name)
                    original.clearRole(name)
                }
            )
            .navigationTitle("Tag")
            .navigationBarTitleDisplayMode(.inline)
        case .harmony(let base):
            HarmonyPage(base: base) { colors in accept(colors) }
        case .photo:
            if let photoImage {
                PhotoPinsPage(image: photoImage) { colors in accept(colors) }
            }
        }
    }

    /// A page hands back colors: an empty palette takes them as they are, one
    /// with colors gets them appended (duplicates by hex skipped). Pops the page,
    /// unless nothing new came of it.
    private func accept(_ colors: [PaletteColor]) {
        var added = 0
        withAnimation(appendAnimation) {
            if draft.colors.isEmpty {
                draft.replaceAll(with: colors)
                added = draft.colors.count
            } else {
                added = draft.append(colors)
            }
        }
        if added == 0 {
            ToastManager.shared.show("Already in this palette", icon: "info.circle")
        } else if !path.isEmpty {
            path.removeLast()
        }
    }

    // MARK: - Draft

    private func append(_ colors: [PaletteColor]) {
        withAnimation(appendAnimation) { _ = draft.append(colors) }
    }

    /// Remove → Undo puts the color back where it was, role included.
    private func removed(_ color: PaletteColor, at index: Int) {
        ToastManager.shared.show("Color removed", icon: "trash.fill") {
            // Something added since may have taken the hex or the role; the
            // draft sorts both out.
            withAnimation(appendAnimation) { _ = draft.reinsert(color, at: index) }
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
            showPhotoPins(for: image)
        }
    }

    /// Opens From a Photo for the image. Waits for the picker or camera to
    /// finish dismissing before pushing.
    private func showPhotoPins(for image: UIImage) {
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            photoImage = image.downsampled(longSide: 2048)
            path.append(.photo)
        }
    }

    private func updateSuggestedName() {
        let hexes = draft.colors.map(\.hex)
        guard hexes.count >= 2 else {
            suggestedName = ""
            return
        }
        var editingID: UUID?
        if case .edit(let id) = mode { editingID = id }
        suggestedName = PaletteNamer.descriptiveName(
            forHexes: hexes,
            existingNames: appData.palettes.filter { $0.id != editingID }.map(\.name)
        )
    }

    // MARK: - Actions

    private func generate() {
        if hasChanges {
            // Leaving throws the draft away, so ask like Cancel does.
            generateAfterDiscard = true
            showDiscardConfirmation = true
        } else {
            appData.activeTab = .generate
            dismiss()
        }
    }

    private func cancel() {
        if hasChanges {
            generateAfterDiscard = false
            showDiscardConfirmation = true
        } else {
            ToastManager.shared.dismissUndo()
            dismiss()
        }
    }

    private func confirm() {
        guard draft.canSave else { return }
        ToastManager.shared.dismissUndo()
        onConfirm(draft, draft.resolvedName(suggestion: suggestedName))
    }
}

// MARK: - Edit Color page

/// Edit Color for one band, pushed inside the editor. The composer works on
/// its own copy; each change goes into the draft unless it would give the
/// palette the same hex twice, which shows the usual inline notice instead.
private struct EditColorPage: View {
    @Binding var draft: PaletteDraft
    let id: UUID
    let onTag: () -> Void

    @State private var color: Color
    @State private var name: String

    init(draft: Binding<PaletteDraft>, id: UUID, onTag: @escaping () -> Void) {
        _draft = draft
        self.id = id
        self.onTag = onTag
        let entry = draft.wrappedValue.colors.first { $0.id == id }
        _color = State(initialValue: entry?.color ?? .gray)
        _name = State(initialValue: entry?.name ?? "")
    }

    private var hex: String { ColorComposer.hexKey(color) }

    private var isDuplicate: Bool {
        draft.colors.contains { $0.id != id && $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }

    var body: some View {
        ColorComposer(
            color: $color,
            name: $name,
            notice: isDuplicate ? "Already in this palette" : nil,
            tag: (role: draft.colors.first(where: { $0.id == id })?.role, onTap: onTag)
        )
        .navigationTitle("Edit Color")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: color) { _, _ in apply() }
        .onChange(of: name) { _, _ in apply() }
    }

    private func apply() {
        guard let entry = draft.colors.first(where: { $0.id == id }) else { return }
        if isDuplicate {
            draft.update(id: id, color: entry.color, hex: entry.hex, name: name)
        } else {
            draft.update(id: id, color: color, hex: hex, name: name)
        }
    }
}

#Preview {
    PaletteEditor(mode: .create, draft: PaletteDraft(), onConfirm: { _, _ in })
        .environmentObject(AppData(inMemory: true))
}
