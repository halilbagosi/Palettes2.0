import SwiftUI

/// Standalone "New Color" sheet for the Colors tab: the shared color editor,
/// starting on a fresh color, with Add. A color that's already saved is
/// flagged under its name before Add, not after.
struct NewColorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    @State private var color = Color(hue: Double.random(in: 0..<1), saturation: 0.65, brightness: 0.88)
    @State private var name = ""

    @State private var duplicateExistingName = ""
    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false

    private var hex: String { ColorComposer.hexKey(color) }

    private var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ColorNamer.name(forHex: hex) : trimmed
    }

    private var notice: String? {
        guard let existing = appData.existingColor(hex: hex) else { return nil }
        return "Already saved as \u{201C}\(existing.name)\u{201D}"
    }

    var body: some View {
        NavigationStack {
            ColorComposer(color: $color, name: $name, namesFollowColor: true, notice: notice)
                .navigationTitle("New Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCancelButton { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        SheetConfirmButton(title: "Add") { create() }
                    }
                }
                .alert("Color Already Exists", isPresented: $showDuplicateAlert) {
                    Button("Rename It") { overwriteExisting() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("\(hex) is already saved as \"\(duplicateExistingName)\". Rename it to \"\(resolvedName)\"?")
                }
                .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                    Button("Save Anyway") { save() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A color named \"\(resolvedName)\" already exists (\(duplicateExistingName)).")
                }
        }
        // Sheets cover the app-root toast overlay, so host one here too.
        .toastOverlay()
    }

    /// Saves the color to the library. A hex or name that's already taken
    /// asks first; otherwise the color is added and the sheet closes.
    private func create() {
        if let existing = appData.existingColor(hex: hex) {
            duplicateExistingName = existing.name
            showDuplicateAlert = true
            return
        }
        if let existing = appData.existingColor(named: resolvedName) {
            duplicateExistingName = existing.HEX
            showNameDuplicateAlert = true
            return
        }
        save()
    }

    private func save() {
        let newColor = ColorViewModel(name: resolvedName, color: color, HEX: hex, usedInPalette: false)
        withAnimation {
            appData.colors.append(newColor)
        }
        dismiss()
    }

    private func overwriteExisting() {
        if let idx = appData.colors.firstIndex(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            appData.colors[idx].name = resolvedName
            appData.colors[idx].color = color
        }
        dismiss()
    }
}

#Preview {
    NewColorView()
        .environmentObject(AppData(inMemory: true))
}
