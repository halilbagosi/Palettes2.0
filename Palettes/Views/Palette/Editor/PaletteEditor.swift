//
//  PaletteEditor.swift
//  Palettes
//
//  The one palette editor, for New Palette and Edit Palette. It works on a
//  `PaletteDraft`: nothing reaches AppData until the confirm button; the
//  wrapper that presents the editor decides what that does.
//
//  Stacked (a tall container): the palette strip, its name, the source switch
//  (Pick · Scan · Library · Harmony) and the add panel, in one vertical scroll
//  view; the panel takes the room left over, never less than it needs.
//  Split (landscape, regular-width, or too short to stack): the strip, name
//  and subtext on one side, the switch and add panel on the other, each side
//  scrolling by itself. With an active fold the sides sit either side of the
//  crease, so controls never land on it.
//

import SwiftUI

enum PaletteEditorRoute: Hashable {
    case edit(UUID)
    case tag(UUID)
}

/// The editor's copy and the sums its layout is made from, kept apart from
/// the view so they can be tested.
enum PaletteEditorCopy {
    /// Under the strip, once there is something to tap or hold.
    static func subtext(colorCount: Int) -> String? {
        colorCount > 0 ? "Tap to edit \u{00B7} long press to remove" : nil
    }

    static func caption(colorCount: Int) -> String {
        colorCount == 1 ? "1 color \u{00B7} add one more to create" : "\(colorCount) colors"
    }

    /// Vertical padding around the stacked content (8 above, 20 below).
    static let stackedPadding: CGFloat = 28

    /// What the stacked layout needs to show everything usably: the four
    /// blocks, the gaps between them and the padding. Callers pass
    /// `@ScaledMetric` heights, so it grows with Dynamic Type.
    static func minStackedHeight(strip: CGFloat, name: CGFloat, picker: CGFloat, panel: CGFloat, spacing: CGFloat) -> CGFloat {
        strip + name + picker + panel + spacing * 3 + stackedPadding
    }
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
    /// Colors that just filled an empty palette, each with its place in the
    /// entrance stagger (see FirstFillStagger). Emptied once it has played.
    @State private var entrance: [UUID: Int] = [:]
    @FocusState private var nameFocused: Bool
    /// A text field in the add panel (Pick's name, Library's search) has focus.
    @State private var panelFieldFocused = false

    // Content-based sizes (scaled with Dynamic Type) the stacked/split
    // decision and the panel's floor are made from.
    /// The strip with its caption and subtext.
    @ScaledMetric(relativeTo: .body) private var stripBlockHeight: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var nameHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var pickerHeight: CGFloat = 32
    /// What the add panel needs to stay usable (Library's search, a few cards
    /// and the Add button).
    @ScaledMetric(relativeTo: .body) private var panelMinHeight: CGFloat = 260
    @AppStorage("paletteAddSource") private var sourceRaw = PaletteAddSource.pick.rawValue

    private static let blockSpacing: CGFloat = 12

    init(mode: Mode, draft: PaletteDraft, onConfirm: @escaping (PaletteDraft, String) -> Void) {
        self.mode = mode
        self.onConfirm = onConfirm
        _draft = State(initialValue: draft)
        _original = State(initialValue: draft)
    }

    private var isCreating: Bool { mode == .create }
    private var hasChanges: Bool { draft != original }

    private var minStackedHeight: CGFloat {
        PaletteEditorCopy.minStackedHeight(
            strip: stripBlockHeight, name: nameHeight, picker: pickerHeight,
            panel: panelMinHeight, spacing: Self.blockSpacing
        )
    }

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

    var body: some View {
        NavigationStack(path: $path) {
            SheetLayoutReader(minStackedHeight: minStackedHeight) { layout, fold in
                // A fold always wins: a crease across stacked content would
                // leave it scrolling over the crease.
                if let fold {
                    FoldSplit(fold: fold) {
                        visualColumn
                    } controls: {
                        controlsColumn
                    }
                } else {
                    switch layout {
                    case .stacked:
                        FillingScroll(minContentHeight: 0) {
                            VStack(spacing: Self.blockSpacing) {
                                stripBlock(fillsHeight: false)
                                nameField
                                sourcePicker
                                addPanel
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                        }
                    case .split:
                        HStack(spacing: 0) {
                            visualColumn.frame(maxWidth: .infinity)
                            controlsColumn.frame(maxWidth: .infinity)
                        }
                    }
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

    // MARK: - Columns

    /// Split's first side: the strip (as tall as the side allows), its name and
    /// subtext. Scrolls when a short container can't fit them.
    private var visualColumn: some View {
        FillingScroll(minContentHeight: 0) {
            VStack(spacing: Self.blockSpacing) {
                stripBlock(fillsHeight: true)
                nameField
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    /// Split's second side: the source switch and the add panel.
    private var controlsColumn: some View {
        FillingScroll(minContentHeight: 0) {
            VStack(spacing: Self.blockSpacing) {
                sourcePicker
                addPanel
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private var sourcePicker: some View {
        Picker("Add colors from", selection: source) {
            ForEach(PaletteAddSource.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .sensoryFeedback(.selection, trigger: sourceRaw)
    }

    /// Takes the room the scroll view has left, but never less than it needs
    /// (so a short container scrolls instead of squeezing the Library's cards).
    private var addPanel: some View {
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
        .frame(maxHeight: .infinity)
        .frame(minHeight: panelMinHeight)
    }

    private var nameField: some View {
        TextField(suggestedName.isEmpty ? "Palette Name" : suggestedName, text: $draft.name)
            .font(.system(size: 18, weight: .medium))
            .submitLabel(.done)
            .focused($nameFocused)
            .onSubmit { nameFocused = false }
            .padding()
            .liquidGlass(.regular, in: .rect(cornerRadius: 16))
            .accessibilityLabel("Palette name")
            .accessibilityHint(nameHint)
    }

    // MARK: - Strip

    /// The palette as it will look, with its caption and subtext.
    /// `fillsHeight`: take whatever height the column has (split), else the
    /// strip's own.
    private func stripBlock(fillsHeight: Bool) -> some View {
        VStack(spacing: 6) {
            if draft.colors.isEmpty {
                emptyPreview(fillsHeight: fillsHeight)
            } else {
                PaletteStripEditor(
                    draft: $draft,
                    selection: $selection,
                    entrance: entrance,
                    fillsHeight: fillsHeight,
                    onEdit: { path.append(.edit($0)) },
                    onTag: { path.append(.tag($0)) },
                    onRemove: { index, color in showUndo(for: color, at: index) }
                )
                // On a first fill the bands fade in themselves; the strip's own
                // fade would multiply with band 0's.
                .transition(entrance.isEmpty ? .opacity : .identity)
            }

            // The caption is always laid out, so the first color doesn't move
            // the list; the subtext appears with the first color.
            VStack(alignment: .leading, spacing: 2) {
                Text(PaletteEditorCopy.caption(colorCount: draft.colors.count))
                    .font(.caption)
                    .opacity(draft.colors.isEmpty ? 0 : 1)
                    .accessibilityHidden(draft.colors.isEmpty)
                if let subtext = PaletteEditorCopy.subtext(colorCount: draft.colors.count) {
                    Text(subtext)
                        .font(.footnote)
                }
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func emptyPreview(fillsHeight: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "swatchpalette")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Add at least 2 colors to build your palette")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: PaletteStripEditor.height, maxHeight: fillsHeight ? .infinity : PaletteStripEditor.height)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
        // Vanish instantly when the first color arrives, so a fading glass
        // rim doesn't read as a stray hairline over the strip.
        .transition(.asymmetric(insertion: .opacity, removal: .identity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Empty palette. Add at least 2 colors to build your palette.")
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
        } else if !staggered.isEmpty {
            clearEntrance(staggered)
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

/// A vertical scroll view whose content is at least as tall as the view, so
/// flexible children (the add panel, a tall strip) fill the room there is and
/// the rest scrolls. Bounces only when the content overflows.
private struct FillingScroll<Content: View>: View {
    var minContentHeight: CGFloat
    @ViewBuilder var content: Content

    @State private var viewport: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .frame(minHeight: max(viewport, minContentHeight))
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewport = $0 }
    }
}
