//
//  PaletteColorPages.swift
//  Palettes
//
//  Pages pushed inside a palette sheet to add colors: compose a new one, or
//  pick several from the library. Both dismiss themselves after adding, which
//  pops back when pushed and closes the sheet when they're its root.
//

import SwiftUI

/// Compose a new color for a palette, then Add.
struct NewPaletteColorPage: View {
    /// Uppercased "#RRGGBB" of colors already in the palette.
    var excludedHexes: Set<String>
    var onAdd: (PaletteColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var color = Color(hue: Double.random(in: 0..<1), saturation: 0.65, brightness: 0.88)
    @State private var name = ""

    private var hex: String { ColorComposer.hexKey(color) }
    private var isDuplicate: Bool { excludedHexes.contains(hex) }

    var body: some View {
        ColorComposer(
            color: $color,
            name: $name,
            namesFollowColor: true,
            notice: isDuplicate ? "Already in this palette" : nil
        )
        .navigationTitle("New Color")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { add() }
                    .fontWeight(.semibold)
                    .disabled(isDuplicate)
            }
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onAdd(PaletteColor(color: color, hex: hex, name: trimmed.isEmpty ? ColorNamer.name(forHex: hex) : trimmed))
        dismiss()
    }
}

/// Multi-select list of the user's saved colors, newest first and
/// searchable. Colors already in the palette show checked and can't be picked
/// again. Optionally starts with a "New Color" row.
struct LibraryColorPicker: View {
    var title: String = "Library"
    /// Uppercased "#RRGGBB" of colors already in the palette.
    var excludedHexes: Set<String>
    var onNewColor: (() -> Void)? = nil
    var onAdd: ([ColorViewModel]) -> Void

    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<UUID> = []
    @State private var search = ""

    private var colors: [ColorViewModel] {
        let items = Array(appData.colors.reversed())
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.HEX.localizedCaseInsensitiveContains(query)
        }
    }

    private var addTitle: String {
        selection.isEmpty ? "Add" : "Add \(selection.count)"
    }

    var body: some View {
        List {
            if let onNewColor, search.isEmpty {
                Section {
                    Button(action: onNewColor) {
                        Label("New Color", systemImage: "plus.circle.fill")
                    }
                }
            }

            if appData.colors.isEmpty {
                ContentUnavailableView(
                    "No Saved Colors",
                    systemImage: "circle.grid.cross",
                    description: Text("Colors you save in the Colors tab appear here.")
                )
                .listRowBackground(Color.clear)
            } else if colors.isEmpty {
                ContentUnavailableView.search(text: search)
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(colors) { item in
                        row(item)
                    }
                } header: {
                    Text("Saved Colors")
                }
            }
        }
        .searchable(text: $search, prompt: "Search Colors")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: selection)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(addTitle) { add() }
                    .fontWeight(.semibold)
                    .disabled(selection.isEmpty)
            }
        }
    }

    private func row(_ item: ColorViewModel) -> some View {
        let alreadyIn = excludedHexes.contains(item.HEX.uppercased())
        let isSelected = selection.contains(item.id)

        return Button {
            if isSelected {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.color.gradient)
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(alreadyIn ? "In palette" : item.HEX)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: alreadyIn || isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadyIn)
        .opacity(alreadyIn ? 0.5 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func add() {
        // Library order (oldest first), so the palette reads the way the
        // colors were saved.
        let picked = appData.colors.filter { selection.contains($0.id) }
        onAdd(picked)
        dismiss()
    }
}
