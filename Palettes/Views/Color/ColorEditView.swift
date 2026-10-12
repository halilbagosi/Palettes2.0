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

    // Working copy, so Cancel leaves the original untouched.
    @State private var internalName: String
    @State private var internalColor: Color

    init(
        colorName: Binding<String>,
        hexCode: Binding<String>,
        colorValue: Binding<Color>,
        onSave: @escaping () -> Void = {}
    ) {
        _colorName = colorName
        _hexCode = hexCode
        _colorValue = colorValue
        self.onSave = onSave
        _internalName = State(initialValue: colorName.wrappedValue)
        _internalColor = State(initialValue: colorValue.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ColorComposer(color: $internalColor, name: $internalName, tinted: true)
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
        }
        // Sheets cover the app-root toast overlay; a tap on a value copies it.
        .toastOverlay()
    }

    private func handleSaveTapped() {
        saveChanges()
        dismiss()
    }

    private func saveChanges() {
        let trimmed = internalName.trimmingCharacters(in: .whitespacesAndNewlines)
        colorName = trimmed.isEmpty ? "Untitled" : trimmed
        hexCode = ColorComposer.hexKey(internalColor)
        colorValue = internalColor
        onSave()
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
