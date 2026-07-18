import SwiftUI

/// Standalone "New Color" sheet for the Colors tab. A thin host around the
/// shared `ColorInputView` engine (same surface the palette add/create sheets
/// use), specialised to save a single color into the global library.
struct NewColorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    @State private var inputController = ColorInputController()
    @State private var isSampling = false

    /// Entry waiting on the user's decision after a duplicate hex was found.
    @State private var duplicateEntry: ColorInputEntry?
    @State private var duplicateExistingName = ""
    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ColorInputView(
                    sources: [.pick, .scan],
                    scanExtraction: .dominant,
                    addButtonTitle: "Create",
                    onAdd: { entry in create(entry) },
                    showsAddButton: false,
                    controller: inputController,
                    onSamplingChanged: { isSampling = $0 }
                )
                .environmentObject(appData)
                .padding(.bottom, 20)
            }
            .scrollDisabled(isSampling)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Color")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { inputController.submit() }
                        .glassButton(prominent: true)
                        .fontWeight(.semibold)
                        .disabled(!inputController.canAdd)
                }
            }
            .alert("Color Already Exists", isPresented: $showDuplicateAlert) {
                Button("Overwrite") {
                    if let entry = duplicateEntry { overwriteExisting(with: entry) }
                }
                Button("Cancel", role: .cancel) { duplicateEntry = nil }
            } message: {
                Text("\(duplicateEntry?.hex ?? "This color") is already saved as \"\(duplicateExistingName)\". Overwrite it with the new name?")
            }
            .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                Button("Save Anyway") {
                    if let entry = duplicateEntry { save(entry) }
                }
                Button("Cancel", role: .cancel) { duplicateEntry = nil }
            } message: {
                Text("A color named \"\(duplicateEntry?.name ?? "")\" already exists (\(duplicateExistingName)).")
            }
        }
    }

    /// Saves a single new color to the library. A hex that already exists
    /// raises the duplicate dialog and the sheet stays open; otherwise the
    /// color is appended and the sheet dismisses.
    private func create(_ entry: ColorInputEntry) {
        if let existing = appData.existingColor(hex: entry.hex) {
            duplicateEntry = entry
            duplicateExistingName = existing.name
            showDuplicateAlert = true
            return
        }
        if let existing = appData.existingColor(named: entry.name) {
            duplicateEntry = entry
            duplicateExistingName = existing.HEX
            showNameDuplicateAlert = true
            return
        }
        save(entry)
    }

    private func save(_ entry: ColorInputEntry) {
        let newColor = ColorViewModel(name: entry.name, color: entry.color, HEX: entry.hex, usedInPalette: false)
        withAnimation {
            appData.colors.append(newColor)
        }
        duplicateEntry = nil
        dismiss()
    }

    private func overwriteExisting(with entry: ColorInputEntry) {
        if let idx = appData.colors.firstIndex(where: { $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame }) {
            appData.colors[idx].name = entry.name
            appData.colors[idx].color = entry.color
        }
        duplicateEntry = nil
        dismiss()
    }
}

#Preview {
    NewColorView()
        .environmentObject(AppData())
}
