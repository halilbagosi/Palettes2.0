//
//  RoleList.swift
//  Palettes
//
//  The tag/role list: built-in `ColorRole.defaults`, app-wide custom tags
//  (`AppData.customTags`), new-tag creation, renaming and deleting tags.
//  It never writes palette data — choosing a role (or removing the tag)
//  reports through `onSelect`, so a host can apply the choice straight to
//  AppData (`RolePickerSheet`) or to an in-progress draft (the palette
//  editor). Creating, renaming and deleting custom tags edit
//  `appData.customTags`, which is app-wide rather than palette data, so those
//  stay here. There is no NavigationStack inside: the host provides it (and
//  the navigation title / toolbar), whether it presents this in a sheet or
//  pushes it onto an existing stack.
//

import SwiftUI

struct RoleList: View {
    /// The role currently held by the color being tagged, if any.
    let current: String?
    /// Called with the chosen role, or `nil` to remove the tag.
    var onSelect: (String?) -> Void
    /// Called after a custom tag is renamed (`appData.renameCustomTag` has
    /// already rewritten saved palettes). A host holding a draft remaps its
    /// own copy so saving doesn't write the old name back.
    var onTagRenamed: ((_ old: String, _ new: String) -> Void)? = nil
    /// Called after a custom tag is deleted, for the same reason.
    var onTagDeleted: ((_ name: String) -> Void)? = nil

    @EnvironmentObject var appData: AppData

    @State private var newTagText = ""
    @State private var newTagError: String?
    @State private var renamingTag: String?
    @State private var renameText = ""

    var body: some View {
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

            if current != nil {
                Section {
                    Button(role: .destructive) {
                        onSelect(nil)
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
                            onTagDeleted?(name)
                        }
                    }
                }
            }
        }
        .softScrollEdge()
        .alert("Rename Tag", isPresented: Binding(
            get: { renamingTag != nil },
            set: { isPresented in if !isPresented { renamingTag = nil } }
        )) {
            TextField("Tag name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingTag = nil }
            Button("Save") {
                if let old = renamingTag {
                    let before = appData.customTags
                    appData.renameCustomTag(old, to: renameText)
                    // AppData ignores empty or taken names; only a real rename
                    // is reported.
                    if appData.customTags != before {
                        onTagRenamed?(old, renameText.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
                renamingTag = nil
            }
        }
    }

    // MARK: - Rows

    /// Each role/tag is rendered as an actual chip — leading tag glyph, bold
    /// label, filled pill — rather than plain list text, so the available
    /// tags read clearly at a glance in the slide-up sheet. The selected one
    /// gets a solid dark fill with a white label (matching the row control in
    /// Edit Palette) plus a trailing checkmark; the rest use a subtle fill
    /// that stays legible in both light and dark mode.
    private func roleRow(_ name: String) -> some View {
        let isSelected = current?.caseInsensitiveCompare(name) == .orderedSame
        return Button {
            onSelect(name)
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected
                        ? AnyShapeStyle(Color(white: 0.22))
                        : AnyShapeStyle(Color(.tertiarySystemFill)))
                )

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(white: 0.22))
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        onSelect(trimmed)
    }
}

#Preview {
    NavigationStack {
        RoleList(current: "Primary", onSelect: { _ in })
            .navigationTitle("Tag")
            .navigationBarTitleDisplayMode(.inline)
    }
    .environmentObject(AppData(inMemory: true))
}
