import SwiftUI

/// "Edit Color" sheet: the shared color editor over a working copy, saved on
/// Save. The same editor as New Color, so a color is shaped the same way
/// whether it's being made or changed.
struct ColorEditView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    // Original bindings
    @Binding var colorName: String
    @Binding var hexCode: String
    @Binding var colorValue: Color

    var onSave: () -> Void = {}
    /// A palette's color: a Tag row opens the tag list, and the chosen tag
    /// is handed to `save` on Save. Library colors have no tag (nil).
    var tag: (current: String?, save: (String?) -> Void)? = nil

    // Working copy, so Cancel leaves the original untouched.
    @State private var internalName: String
    @State private var internalColor: Color
    @State private var internalRole: String?
    @State private var showsTags = false
    @State private var showNameTakenAlert = false

    init(
        colorName: Binding<String>,
        hexCode: Binding<String>,
        colorValue: Binding<Color>,
        tag: (current: String?, save: (String?) -> Void)? = nil,
        onSave: @escaping () -> Void = {}
    ) {
        _colorName = colorName
        _hexCode = hexCode
        _colorValue = colorValue
        self.tag = tag
        self.onSave = onSave
        _internalName = State(initialValue: colorName.wrappedValue)
        _internalColor = State(initialValue: colorValue.wrappedValue)
        _internalRole = State(initialValue: tag?.current)
    }

    var body: some View {
        NavigationStack {
            ColorComposer(
                color: $internalColor,
                name: $internalName,
                tinted: true,
                tag: tag.map { _ in (role: internalRole, onTap: { showsTags = true }) }
            )
                .navigationTitle("Edit Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCancelButton { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SheetConfirmButton(kind: .save) { handleSaveTapped() }
                    }
                }
                .alert("Name Already Exists", isPresented: $showNameTakenAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Another color is already named \"\(internalName.trimmingCharacters(in: .whitespacesAndNewlines))\". Choose a different name.")
                }
                .navigationDestination(isPresented: $showsTags) {
                    RoleList(
                        current: internalRole,
                        onSelect: { role in
                            internalRole = role
                            showsTags = false
                        },
                        onTagRenamed: { old, new in
                            if internalRole?.caseInsensitiveCompare(old) == .orderedSame { internalRole = new }
                        },
                        onTagDeleted: { name in
                            if internalRole?.caseInsensitiveCompare(name) == .orderedSame { internalRole = nil }
                        }
                    )
                    .navigationTitle("Tag")
                    .navigationBarTitleDisplayMode(.inline)
                }
        }
        // Sheets cover the app-root toast overlay; a tap on a value copies it.
        .toastOverlay()
    }

    /// A library color can't take another library color's name. Palette
    /// colors (`tag` set) name only their slot, so they aren't checked.
    private var nameIsTaken: Bool {
        guard tag == nil else { return false }
        let trimmed = internalName.trimmingCharacters(in: .whitespacesAndNewlines)
        return appData.colors.contains {
            $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
                && $0.HEX.caseInsensitiveCompare(hexCode) != .orderedSame
        }
    }

    private func handleSaveTapped() {
        if nameIsTaken {
            showNameTakenAlert = true
            return
        }
        saveChanges()
        dismiss()
    }

    private func saveChanges() {
        let trimmed = internalName.trimmingCharacters(in: .whitespacesAndNewlines)
        colorName = trimmed.isEmpty ? "Untitled" : trimmed
        hexCode = ColorComposer.hexKey(internalColor)
        colorValue = internalColor
        onSave()
        if let tag, internalRole != tag.current { tag.save(internalRole) }
    }
}

#Preview {
    ColorEditView(
        colorName: .constant("Crimson"),
        hexCode: .constant("#DC143C"),
        colorValue: .constant(Color(red: 220/255, green: 20/255, blue: 60/255))
    )
    .environmentObject(AppData(inMemory: true))
}
