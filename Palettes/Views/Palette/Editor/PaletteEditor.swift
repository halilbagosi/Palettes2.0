//
//  PaletteEditor.swift
//  Palettes
//
//  The one palette editor, for New Palette and Edit Palette, laid out like the
//  New Palette sheet: the palette strip pinned at the top (tap a band to edit
//  it, hold to reorder), a scrolling middle with the name and the "Added
//  Colors" rows, and the add panel pinned at the bottom (Pick · Scan · Library
//  · Harmony). It works on a `PaletteDraft`: nothing reaches AppData until ✓;
//  the wrapper that presents the editor decides what ✓ does.
//

import SwiftUI

enum PaletteEditorRoute: Hashable {
    case edit(UUID)
    case tag(UUID)
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
    /// The first row the add panel just added; the list scrolls to it.
    @State private var scrollTarget: UUID?
    /// Colors that just filled an empty palette, each with its place in the
    /// entrance stagger (see FirstFillStagger). Emptied once it has played.
    @State private var entrance: [UUID: Int] = [:]
    @FocusState private var nameFocused: Bool
    /// A text field in the add panel (Pick's name, Library's search) has focus.
    @State private var panelFieldFocused = false
    /// Height of the on-screen software keyboard, 0 when there is none (or a
    /// hardware keyboard is attached): focus alone doesn't mean a keyboard
    /// took any room.
    @State private var keyboardHeight: CGFloat = 0
    /// The editor's height before a keyboard took some, so the bands keep
    /// their sizes while one is up.
    @State private var stableHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1
    @AppStorage("paletteAddSource") private var sourceRaw = PaletteAddSource.pick.rawValue

    init(mode: Mode, draft: PaletteDraft, onConfirm: @escaping (PaletteDraft, String) -> Void) {
        self.mode = mode
        self.onConfirm = onConfirm
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    private var isCreating: Bool { mode == .create }
    private var hasChanges: Bool { draft != original }
    private var softKeyboardUp: Bool { keyboardHeight > Self.softKeyboardThreshold }
    /// The palette's name is being typed on a software keyboard: the panel steps aside.
    private var nameKeyboard: Bool { nameFocused && softKeyboardUp }
    /// A panel field is being typed in: the strip and list step aside instead.
    private var panelKeyboard: Bool { panelFieldFocused && softKeyboardUp }

    /// A hardware keyboard shows at most a shortcut bar, far below this.
    private static let softKeyboardThreshold: CGFloat = 120

    private var source: Binding<PaletteAddSource> {
        Binding(
            get: { PaletteAddSource(rawValue: sourceRaw) ?? .pick },
            set: { sourceRaw = $0.rawValue }
        )
    }

    private var nameHint: String {
        suggestedName.isEmpty ? "Names the palette" : "Leave blank to use \(suggestedName)"
    }

    /// Rows and bands moving to make or close room. Reduce Motion: no layout
    /// movement at all (nil); the first-fill entrance fades by itself.
    private var appendAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    private var keyboardAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let available = stableHeight > 0 ? stableHeight : geo.size.height
                let preferred = PaletteEditorLayout.panelHeight(
                    available: available,
                    minimum: PaletteEditorLayout.minimum(typeScale: typeScale)
                )
                // With the strip and list stepped aside, the panel still has
                // to fit in what the keyboard leaves.
                let panelHeight = panelKeyboard ? min(preferred, max(geo.size.height - 12, 0)) : preferred

                VStack(spacing: 0) {
                    // Typing in the panel needs the room: the strip and list
                    // step aside (hidden, not removed, so their state stays).
                    VStack(spacing: 0) {
                        header
                        list
                    }
                    .frame(maxHeight: panelKeyboard ? 0 : .infinity)
                    .clipped()
                    .opacity(panelKeyboard ? 0 : 1)
                    .allowsHitTesting(!panelKeyboard)
                    .accessibilityHidden(panelKeyboard)

                    PaletteAddPanel(
                        draft: draft,
                        selection: $selection,
                        source: source,
                        height: panelHeight,
                        fieldFocused: $panelFieldFocused,
                        onAdd: add
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    // The palette's own name field needs the whole screen
                    // above the keyboard.
                    .frame(height: nameKeyboard ? 0 : panelHeight + 12, alignment: .top)
                    .clipped()
                    .opacity(nameKeyboard ? 0 : 1)
                    .allowsHitTesting(!nameKeyboard)
                    .accessibilityHidden(nameKeyboard)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .animation(keyboardAnimation, value: nameKeyboard)
                .animation(keyboardAnimation, value: panelKeyboard)
                .onChange(of: geo.size.height, initial: true) { _, height in
                    // Heights seen while a keyboard is up are not the editor's own.
                    if !(softKeyboardUp || nameFocused || panelFieldFocused) { stableHeight = height }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                    keyboardHeight = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardHeight = 0
                }
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

    // MARK: - Strip

    /// The palette as it will look, pinned so it stays in view while the list
    /// scrolls and the panel is used.
    private var header: some View {
        VStack(spacing: 6) {
            if draft.colors.isEmpty {
                emptyPreview
            } else {
                PaletteStripEditor(
                    draft: $draft,
                    selection: $selection,
                    entrance: entrance,
                    onEdit: { path.append(.edit($0)) },
                    onTag: { path.append(.tag($0)) },
                    onRemove: { index, color in showUndo(for: color, at: index) }
                )
                // On a first fill the bands fade in themselves; the strip's own
                // fade would multiply with band 0's.
                .transition(entrance.isEmpty ? .opacity : .identity)
            }

            // Always laid out, so the first color doesn't move the list.
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(draft.colors.isEmpty ? 0 : 1)
                .accessibilityHidden(draft.colors.isEmpty)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var caption: String {
        let count = draft.colors.count
        if count == 1 { return "1 color \u{00B7} add one more to create" }
        return "\(count) colors"
    }

    private var emptyPreview: some View {
        VStack(spacing: 6) {
            Image(systemName: "swatchpalette")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Add at least 2 colors to build your palette")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
        // Vanish instantly when the first color arrives, so a fading glass
        // rim doesn't read as a stray hairline over the strip.
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Empty palette. Add at least 2 colors to build your palette.")
    }

    // MARK: - List

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $draft.name)
                        .font(.system(size: 18, weight: .medium))
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { nameFocused = false }
                        .padding()
                        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                        .accessibilityLabel("Palette name")
                        .accessibilityHint(nameHint)

                    if !draft.colors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Added Colors")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityAddTraits(.isHeader)

                            LazyVStack(spacing: 8) {
                                ForEach(draft.colors) { entry in
                                    PaletteColorRow(
                                        color: entry,
                                        onEdit: { selection = entry.id; path.append(.edit(entry.id)) },
                                        onRemove: { removeColor(entry.id) }
                                    )
                                    .firstFillEntrance(index: entrance[entry.id])
                                    // A staggered row fades in by itself.
                                    .transition(entrance[entry.id] == nil ? .opacity : .identity)
                                }
                            }
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .softScrollEdge()
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                scrollTarget = nil
                withAnimation(appendAnimation) { proxy.scrollTo(target, anchor: .center) }
            }
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func destination(for route: PaletteEditorRoute) -> some View {
        switch route {
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
        }
    }

    // MARK: - Draft

    /// Colors from the add panel are appended (duplicates by hex skipped). An
    /// empty palette takes them as they are, which is the same thing.
    private func add(_ colors: [PaletteColor]) {
        let before = draft.colors.count
        var added = 0
        var staggered: [UUID: Int] = [:]
        withAnimation(appendAnimation) {
            added = draft.append(colors)
            // Set in the same update that inserts the views, so they start hidden.
            staggered = FirstFillStagger.plan(existingCount: before, added: draft.colors.dropFirst(before).map(\.id))
            // Only a real plan replaces the current one, so a quick second
            // add doesn't cut a running entrance short.
            if !staggered.isEmpty { entrance = staggered }
        }
        if added == 0 {
            ToastManager.shared.show("Already in this palette", icon: "info.circle")
        } else {
            if !staggered.isEmpty { clearEntrance(staggered) }
            // Show what was just added (not on Undo or Duplicate).
            scrollTarget = draft.colors[before].id
        }
    }

    /// Drops the entrance plan once it has played, so a row that scrolls into
    /// view later doesn't animate in again.
    private func clearEntrance(_ plan: [UUID: Int]) {
        let wait = FirstFillStagger.totalDuration(count: plan.count)
        Task {
            try? await Task.sleep(for: .seconds(wait + 0.1))
            for id in plan.keys { entrance[id] = nil }
        }
    }

    /// The row's minus: remove, then offer Undo.
    private func removeColor(_ id: UUID) {
        var removed: (index: Int, color: PaletteColor)?
        withAnimation(appendAnimation) { removed = draft.remove(id: id) }
        guard let removed else { return }
        if selection == id { selection = nil }
        showUndo(for: removed.color, at: removed.index)
    }

    /// Remove → Undo puts the color back where it was, role included.
    private func showUndo(for color: PaletteColor, at index: Int) {
        ToastManager.shared.show("Color removed", icon: "trash.fill") {
            // Something added since may have taken the hex or the role; the
            // draft sorts both out.
            withAnimation(appendAnimation) { _ = draft.reinsert(color, at: index) }
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

    private func cancel() {
        if hasChanges {
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
