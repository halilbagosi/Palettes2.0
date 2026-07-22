//
//  RolePickerSheet.swift
//  Palettes
//
//  Lets the user tag a palette color with a role: one of the built-in
//  `ColorRole.defaults`, or an app-wide custom tag (`AppData.customTags`).
//  Enforces one-role-per-palette uniqueness: assigning a role that's already
//  held by another color in the same palette clears it there first. Mutates
//  `appData.palettes` directly by index — the same palette-update path
//  `PaletteEditSheet` uses for editing a palette color's hex/name/color.
//

import SwiftUI

struct RolePickerSheet: View {
    let currentRole: String?
    let palette: PaletteViewModel
    let colorIndex: Int

    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    @State private var newTagText = ""
    @State private var newTagError: String?
    @State private var renamingTag: String?
    @State private var renameText = ""

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == palette.id })
    }

    /// The color's role read live from `appData`, so the checkmark and the
    /// "Remove Tag" section stay in sync as soon as a selection is made,
    /// without needing to dismiss and reopen the sheet.
    private var liveCurrentRole: String? {
        guard let idx = paletteIndex, colorIndex < appData.palettes[idx].paletteColors.count else {
            return currentRole
        }
        return appData.palettes[idx].paletteColors[colorIndex].role
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Role") {
                    ForEach(ColorRole.defaults) { role in
                        roleRow(role.name)
                    }
                }

                if !appData.customTags.isEmpty {
                    Section("Custom Tags") {
                        ForEach(appData.customTags, id: \.self) { tag in
                            roleRow(tag)
                        }
                    }
                }

                Section {
                    HStack {
                        TextField("New tag…", text: $newTagText)
                            .autocorrectionDisabled()
                            .onChange(of: newTagText) { _, _ in newTagError = nil }
                        Button("Add") {
                            addTag()
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let newTagError {
                        Text(newTagError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("New Tag")
                }

                if liveCurrentRole != nil {
                    Section {
                        Button(role: .destructive) {
                            assign(role: nil)
                        } label: {
                            Text("Remove Tag")
                        }
                    }
                }

                if !appData.customTags.isEmpty {
                    Section("Manage Tags") {
                        ForEach(appData.customTags, id: \.self) { tag in
                            manageTagRow(tag)
                        }
                        .onDelete { offsets in
                            for name in offsets.map({ appData.customTags[$0] }) {
                                appData.deleteCustomTag(name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tag Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Tag", isPresented: Binding(
                get: { renamingTag != nil },
                set: { isPresented in if !isPresented { renamingTag = nil } }
            )) {
                TextField("Tag name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingTag = nil }
                Button("Save") {
                    if let old = renamingTag {
                        appData.renameCustomTag(old, to: renameText)
                    }
                    renamingTag = nil
                }
            }
        }
    }

    // MARK: - Rows

    private func roleRow(_ name: String) -> some View {
        Button {
            assign(role: name)
        } label: {
            HStack {
                Text(name)
                    .foregroundStyle(.primary)
                Spacer()
                if liveCurrentRole?.caseInsensitiveCompare(name) == .orderedSame {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func manageTagRow(_ tag: String) -> some View {
        HStack {
            Text(tag)
            Spacer()
            Button {
                renameText = tag
                renamingTag = tag
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: - Actions

    private func addTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard appData.addCustomTag(trimmed) else {
            newTagError = "That tag name is already in use."
            return
        }
        newTagError = nil
        newTagText = ""
        assign(role: trimmed)
    }

    /// Assigns `role` to `colorIndex` in the palette. If another color in the
    /// same palette already holds `role`, that color is cleared first so a
    /// role only ever has one holder per palette.
    ///
    /// The sheet is dismissed *before* the mutation is applied, and the
    /// mutation itself is deferred until after the dismissal animation
    /// finishes. `RoleBadge`'s scale+opacity transition on
    /// `PaletteDetailView` (see its `.animation(value: role)`) only plays
    /// when the state change lands on a visible view — applying it while
    /// this sheet still covers the detail view makes SwiftUI snap it in
    /// flat instead of animating it in. `paletteIndex`/`colorIndex` are
    /// re-validated after the delay since the palette's colors can change
    /// while the sheet is closing.
    private func assign(role: String?) {
        guard let idx = paletteIndex, colorIndex < appData.palettes[idx].paletteColors.count else { return }

        dismiss()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))

            guard let idx = paletteIndex,
                  colorIndex >= 0,
                  colorIndex < appData.palettes[idx].paletteColors.count else { return }

            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if let role {
                    for j in appData.palettes[idx].paletteColors.indices where j != colorIndex {
                        if appData.palettes[idx].paletteColors[j].role?.caseInsensitiveCompare(role) == .orderedSame {
                            appData.palettes[idx].paletteColors[j].role = nil
                        }
                    }
                }

                appData.palettes[idx].paletteColors[colorIndex].role = role
            }
        }
    }
}

#Preview {
    RolePickerSheet(
        currentRole: "Primary",
        palette: PaletteViewModel(
            name: "Preview Palette",
            colors: [.red, .blue],
            hexCodes: ["#FF0000", "#0000FF"],
            colorNames: ["Red", "Blue"],
            colorRoles: ["Primary", ""]
        ),
        colorIndex: 0
    )
    .environmentObject(AppData(inMemory: true))
}
