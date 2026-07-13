import SwiftUI

/// Standalone "New Color" sheet for the Colors tab. A thin host around the
/// shared `ColorInputView` engine (same surface the palette add/create sheets
/// use), specialised to save a single color into the global library.
struct NewColorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    var body: some View {
        NavigationStack {
            ScrollView {
                ColorInputView(
                    sources: [.pick, .scan],
                    scanExtraction: .dominant,
                    addButtonTitle: "Create",
                    onAdd: { entry in create(entry) }
                )
                .environmentObject(appData)
                .padding(.bottom, 20)
            }
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
            }
        }
    }

    /// Saves a single new color to the library. A hex that already exists is
    /// surfaced with a toast and the sheet stays open; otherwise the color is
    /// appended and the sheet dismisses.
    private func create(_ entry: ColorInputEntry) {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(entry.hex) == .orderedSame }) {
            ToastManager.shared.show("Already exists as '\(existing.name)'", icon: "exclamationmark.circle.fill")
            return
        }
        let newColor = ColorViewModel(name: entry.name, color: entry.color, HEX: entry.hex, usedInPalette: false)
        withAnimation {
            appData.colors.append(newColor)
        }
        dismiss()
    }
}

#Preview {
    NewColorView()
        .environmentObject(AppData())
}
