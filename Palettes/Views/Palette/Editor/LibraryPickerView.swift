//
//  LibraryPickerView.swift
//  Palettes
//
//  The add panel's Library source: the user's saved colors, newest first and
//  searchable, as a multi-select. Colors already in the palette show checked
//  and can't be picked again. "+ Add N" hands the picked colors to the editor.
//  Tap-only, so it may scroll.
//

import SwiftUI

struct LibraryPickerView: View {
    /// Uppercased "#RRGGBB" of colors already in the palette.
    var excludedHexes: Set<String>
    var onAdd: ([ColorViewModel]) -> Void

    @EnvironmentObject private var appData: AppData
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

                ScrollView {
                    LazyVStack(spacing: 6) {
                        if colors.isEmpty {
                            Text("No colors match \u{201C}\(search)\u{201D}")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 24)
                        } else {
                            ForEach(colors) { item in
                                row(item)
                            }
                        }
                    }
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Button(action: add) {
                    Label(pickable.isEmpty ? "Add" : "Add \(pickable.count)", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .glassButton(prominent: true)
                .controlSize(.large)
                .disabled(pickable.isEmpty)
            }
            .sensoryFeedback(.selection, trigger: selection)
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
        .panelWell(in: .rect(cornerRadius: 12))
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(item.color.gradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.subheadline)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .panelWell(in: .rect(cornerRadius: 12))
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
        let picked = pickable
        selection = []
        onAdd(picked)
    }
}

#Preview {
    LibraryPickerView(excludedHexes: [], onAdd: { _ in })
        .frame(height: 300)
        .padding()
        .environmentObject(AppData(inMemory: true))
}
