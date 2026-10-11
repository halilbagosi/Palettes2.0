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

    var promptOnNameMatch: Bool = false
    var onSaveWithAction: ((_ isOverwrite: Bool) -> Void)? = nil
    var onSave: () -> Void = {}

    // Working copy, so Cancel leaves the original untouched.
    @State private var internalName: String
    @State private var internalColor: Color
    private let originalName: String
    private let originalHex: String
    @State private var showOverwriteAlert = false

    init(
        colorName: Binding<String>,
        hexCode: Binding<String>,
        colorValue: Binding<Color>,
        promptOnNameMatch: Bool = false,
        onSaveWithAction: ((_ isOverwrite: Bool) -> Void)? = nil,
        onSave: @escaping () -> Void = {}
    ) {
        _colorName = colorName
        _hexCode = hexCode
        _colorValue = colorValue
        self.promptOnNameMatch = promptOnNameMatch
        self.onSaveWithAction = onSaveWithAction
        self.onSave = onSave
        _internalName = State(initialValue: colorName.wrappedValue)
        _internalColor = State(initialValue: colorValue.wrappedValue)
        originalName = colorName.wrappedValue
        let hex = hexCode.wrappedValue
        originalHex = hex.hasPrefix("#") ? hex : "#\(hex)"
    }

    var body: some View {
        NavigationStack {
            ColorComposer(color: $internalColor, name: $internalName)
                .navigationTitle("Edit Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCancelButton { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SheetConfirmButton(title: "Save") { handleSaveTapped() }
                    }
                }
                .alert("Overwrite or Create New?", isPresented: $showOverwriteAlert) {
                    Button("Overwrite Existing") {
                        saveChanges(isOverwrite: true)
                        dismiss()
                    }
                    Button("Create New Color") {
                        saveChanges(isOverwrite: false)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You changed this color without changing its name. Would you like to overwrite it globally or create a new global color?")
                }
        }
    }

    private func handleSaveTapped() {
        let hasHexChanged = ColorComposer.hexKey(internalColor).caseInsensitiveCompare(originalHex) != .orderedSame
        let hasNameChanged = internalName != originalName

        if promptOnNameMatch && !hasNameChanged && hasHexChanged {
            showOverwriteAlert = true
        } else {
            saveChanges(isOverwrite: false)
            dismiss()
        }
    }

    private func saveChanges(isOverwrite: Bool) {
        let trimmed = internalName.trimmingCharacters(in: .whitespacesAndNewlines)
        colorName = trimmed.isEmpty ? "Untitled" : trimmed
        hexCode = ColorComposer.hexKey(internalColor)
        colorValue = internalColor

        if let action = onSaveWithAction {
            action(isOverwrite)
        } else {
            onSave()
        }
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
