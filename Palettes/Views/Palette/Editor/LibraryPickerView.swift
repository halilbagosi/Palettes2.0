//
//  LibraryPickerView.swift
//  Palettes
//
//  The add panel's Library source: the user's saved colors, newest first and
//  searchable, as a multi-select grid of cards (about three to a row).
//  Colors already in the palette show checked and can't be picked again.
//  "+ Add N" hands the picked colors to the editor. Tap-only, so it may
//  scroll.
//

import SwiftUI

struct LibraryPickerView: View {
    /// Uppercased "#RRGGBB" of colors already in the palette.
    var excludedHexes: Set<String>
    /// The search field has the keyboard, so the editor scrolls the panel into view.
    @Binding var searchFocused: Bool
    var onAdd: ([ColorViewModel]) -> Void

    @EnvironmentObject private var appData: AppData
    @State private var selection: Set<UUID> = []
    @State private var search = ""
    @FocusState private var searchIsFocused: Bool

    private var colors: [ColorViewModel] {
        let items = Array(appData.colors.reversed())
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.HEX.localizedCaseInsensitiveContains(query)
        }
    }

    /// The selection minus anything that has joined the palette since.
    private var pickable: [ColorViewModel] {
        appData.colors.filter { selection.contains($0.id) && !excludedHexes.contains($0.HEX.uppercased()) }
    }

    var body: some View {
        if appData.colors.isEmpty {
            emptyState
        } else {
            VStack(spacing: 8) {
                searchField

                FadingScrollView {
                    if colors.isEmpty {
                        Text("No colors match \u{201C}\(search)\u{201D}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        FoldAwareGrid(minimum: 96, maximum: 160, spacing: SwatchCardGrid.spacing, rowSpacing: SwatchCardGrid.spacing) {
                            ForEach(colors) { item in
                                card(item)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button(action: add) {
                    Label(pickable.isEmpty ? "Add" : "Add \(pickable.count)", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .glassButton(prominent: true)
                .controlSize(.large)
                .accessibilityLabel(pickable.isEmpty ? "Add" : "Add \(pickable.count) \(pickable.count == 1 ? "color" : "colors")")
                .disabled(pickable.isEmpty)
            }
            .sensoryFeedback(.selection, trigger: selection)
            .onChange(of: searchIsFocused) { _, focused in searchFocused = focused }
            .onDisappear { searchFocused = false }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "circle.grid.cross")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Saved Colors")
                .font(.subheadline.weight(.semibold))
            Text("Colors you save in the Colors tab appear here.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search Colors", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchIsFocused)
                .onSubmit { searchIsFocused = false }
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .liquidGlass(.regular, in: .rect(cornerRadius: 12))
    }

    private func card(_ item: ColorViewModel) -> some View {
        let alreadyIn = excludedHexes.contains(item.HEX.uppercased())
        let isSelected = selection.contains(item.id)

        return Button {
            if isSelected {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } label: {
            SwatchCard(color: item.color, name: item.name, hex: alreadyIn ? "In palette" : item.HEX) {
                Image(systemName: alreadyIn || isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, isSelected ? Color.accentColor : Color.black.opacity(0.35))
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadyIn)
        .opacity(alreadyIn ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(alreadyIn ? "in palette" : item.HEX)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func add() {
        // Library order (oldest first), so the palette reads the way the
        // colors were saved.
        let picked = pickable
        selection = []
        onAdd(picked)
    }
}

#Preview {
    LibraryPickerView(excludedHexes: [], searchFocused: .constant(false), onAdd: { _ in })
        .frame(height: 300)
        .padding()
        .environmentObject(AppData(inMemory: true))
}
