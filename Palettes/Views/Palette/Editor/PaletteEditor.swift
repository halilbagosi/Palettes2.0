//
//  PaletteEditor.swift
//  Palettes
//
//  The one palette editor, for New Palette and Edit Palette. Top to bottom:
//  the palette strip (tap a band to edit it, hold to reorder), the name, the
//  source switch (Pick · Scan · Library · Harmony), "Added Colors" (a
//  collapsible grid of cards, one and a half rows tall before it scrolls) and
//  the selected source's view, which takes the rest of the sheet. It works on a `PaletteDraft`: nothing reaches AppData until ✓;
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
    /// The Added Colors grid is shown (it starts collapsed).
    @State private var addedExpanded = false
    /// The strip, name, switch and Added Colors header: what the grid's share
    /// of the top two thirds leaves out.
    @State private var fixedUpperHeight: CGFloat = 0
    @State private var gridContentHeight: CGFloat = 0
    /// One card's height, so the grid can show one and a half rows.
    @State private var cardHeight: CGFloat = 0
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
    /// The most of the sheet the strip, name, switch and Added Colors take
    /// (a guard for short screens; the grid's own limit is `visibleRows`).
    private static let upperShare: CGFloat = 2.0 / 3.0
    /// Rows the Added Colors grid shows before it scrolls; the half row tells
    /// the user there is more. The rest of the room goes to the source's view.
    private static let visibleRows: CGFloat = 1.5

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
                // The grid scrolls within what the fixed parts leave of the top
                // two thirds (12 is the gap above it).
                let gridMax = max(available * Self.upperShare - fixedUpperHeight - 12, 0)

                VStack(spacing: 0) {
                    // Typing in the source's view needs the room: the top steps
                    // aside (hidden, not removed, so its state stays).
                    upper(gridMax: gridMax)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .frame(height: panelKeyboard ? 0 : nil, alignment: .top)
                        .clipped()
                        .opacity(panelKeyboard ? 0 : 1)
                        .allowsHitTesting(!panelKeyboard)
                        .accessibilityHidden(panelKeyboard)

                    PaletteAddPanel(
                        draft: draft,
                        selection: $selection,
                        source: source.wrappedValue,
                        fieldFocused: $panelFieldFocused,
                        onAdd: { add($0) },
                        onScan: { add($0, replacing: $1) },
                        onPicked: applyPicked,
                        onRemovePhoto: removePhoto
                    )
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    // The palette's own name field needs the whole screen
                    // above the keyboard.
                    .frame(maxHeight: nameKeyboard ? 0 : .infinity)
                    .clipped()
                    .opacity(nameKeyboard ? 0 : 1)
                    .allowsHitTesting(!nameKeyboard)
                    .accessibilityHidden(nameKeyboard)
                }
                .frame(maxHeight: .infinity, alignment: .top)
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

    /// The palette as it will look, always in view.
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
        .frame(height: PaletteStripEditor.height)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
        // Vanish instantly when the first color arrives, so a fading glass
        // rim doesn't read as a stray hairline over the strip.
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Empty palette. Add at least 2 colors to build your palette.")
    }

    // MARK: - Top

    private func upper(gridMax: CGFloat) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 12) {
                header

                TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $draft.name)
                    .font(.system(size: 18, weight: .medium))
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit { nameFocused = false }
                    .padding()
                    .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                    .accessibilityLabel("Palette name")
                    .accessibilityHint(nameHint)

                Picker("Add colors from", selection: source) {
                    ForEach(PaletteAddSource.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: sourceRaw)

                if !draft.colors.isEmpty {
                    addedHeader
                }
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { fixedUpperHeight = $0 }

            if addedExpanded && !draft.colors.isEmpty {
                addedGrid(maxHeight: gridMax)
                    .transition(.opacity)
            }
        }
    }

    private var addedHeader: some View {
        Button {
            withAnimation(appendAnimation ?? .easeInOut(duration: 0.2)) { addedExpanded.toggle() }
        } label: {
            HStack {
                Text("Added Colors")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .rotationEffect(.degrees(addedExpanded ? 90 : 0))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Added Colors")
        .accessibilityValue(addedExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(addedExpanded ? "Hides the colors" : "Shows the colors")
        .accessibilityAddTraits(.isHeader)
    }

    /// The grid's height for `visibleRows` rows (its 4 pt top padding, the
    /// cards and the gaps between whole rows), once a card has been measured.
    private var rowsHeight: CGFloat {
        guard cardHeight > 0 else { return .infinity }
        let rows = Self.visibleRows
        return 4 + cardHeight * rows + SwatchCardGrid.spacing * rows.rounded(.down)
    }

    /// Three cards to a row, one and a half rows tall; the rest scrolls.
    private func addedGrid(maxHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            FadingScrollView {
                LazyVGrid(columns: SwatchCardGrid.columns, spacing: SwatchCardGrid.spacing) {
                    ForEach(draft.colors) { entry in
                        PaletteColorCard(
                            color: entry,
                            onEdit: { selection = entry.id; path.append(.edit(entry.id)) },
                            onRemove: { removeColor(entry.id) }
                        )
                        .firstFillEntrance(index: entrance[entry.id])
                        // A staggered card fades in by itself.
                        .transition(entrance[entry.id] == nil ? .opacity : .identity)
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { cardHeight = $0 }
                    }
                }
                .padding(.vertical, 4)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { gridContentHeight = $0 }
            }
            .frame(height: min(gridContentHeight, rowsHeight, maxHeight))
            .scrollIndicators(.hidden)
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
    /// empty palette takes them as they are, which is the same thing. A new
    /// Scan photo's colors take the place of the previous photo's (`replacing`).
    private func add(_ colors: [PaletteColor], replacing ids: Set<UUID> = []) {
        let kept = draft.colors.count(where: { !ids.contains($0.id) })
        var result = (index: 0, added: 0)
        var staggered: [UUID: Int] = [:]
        if let selection, ids.contains(selection) { self.selection = nil }
        withAnimation(appendAnimation) {
            result = draft.replace(ids, with: colors)
            let inserted = draft.colors[result.index ..< result.index + result.added].map(\.id)
            // Set in the same update that inserts the views, so they start hidden.
            staggered = FirstFillStagger.plan(existingCount: kept, added: inserted)
            // Only a real plan replaces the current one, so a quick second
            // add doesn't cut a running entrance short.
            if !staggered.isEmpty { entrance = staggered }
        }
        if result.added == 0 {
            ToastManager.shared.show("Already in this palette", icon: "info.circle")
        } else {
            if !staggered.isEmpty { clearEntrance(staggered) }
            // Show what was just added (not on Undo or Duplicate).
            if addedExpanded { scrollTarget = draft.colors[result.index].id }
        }
    }

    /// Scan's Remove: the photo's colors come out too; Undo puts both back.
    private func removePhoto(_ removed: PaletteScanSession.Removed, undo: @escaping () -> Void) {
        let taken = draft.colors.enumerated()
            .filter { removed.colorIDs.contains($0.element.id) }
            .map { (index: $0.offset, color: $0.element) }
        withAnimation(appendAnimation) {
            for entry in taken { draft.remove(id: entry.color.id) }
        }
        if let selection, removed.colorIDs.contains(selection) { self.selection = nil }
        ToastManager.shared.show("Photo removed", icon: "trash.fill") {
            withAnimation(appendAnimation) {
                // In order, so each lands where it was.
                for entry in taken { _ = draft.reinsert(entry.color, at: entry.index) }
            }
            undo()
        }
    }

    /// Colors moved in Scan's picker take their new values, unless that would
    /// give the palette the same hex twice; those keep what they had.
    private func applyPicked(_ picked: [PaletteColor]) {
        var finalHex = Dictionary(uniqueKeysWithValues: draft.colors.map { ($0.id, $0.hex.uppercased()) })
        for color in picked where finalHex[color.id] != nil { finalHex[color.id] = color.hex.uppercased() }
        var skipped = 0
        withAnimation(appendAnimation) {
            for color in picked where finalHex[color.id] != nil {
                let taken = finalHex.contains { $0.key != color.id && $0.value == color.hex.uppercased() }
                if taken {
                    skipped += 1
                } else {
                    draft.update(id: color.id, color: color.color, hex: color.hex, name: color.name)
                }
            }
        }
        if skipped > 0 {
            ToastManager.shared.show("Already in this palette", icon: "info.circle")
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
            tinted: true,
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
