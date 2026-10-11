//
//  LibraryOptionsMenu.swift
//  Palettes
//
//  Contents of the view-options toolbar menu shared by the Palettes and
//  Colors libraries. Place inside
//  `Menu { LibraryOptionsMenu(...) } label: { LibraryOptionsLabel() }`.
//
//  The HIG reserves the ellipsis for overflow menus (on iPhone Duo the system
//  overflow menu is where toolbar items go when bars run out of room), so the
//  options menu uses its own symbol. Every toolbar item here carries a title
//  and a symbol: the system shows the symbol in vertical and horizontal bars
//  and both in the overflow menu; an item with only a title can't go in a
//  vertical bar at all.
//

import SwiftUI

struct LibraryOptionsMenu: View {
    @Binding var layout: ListLayout
    @Binding var sort: LibrarySort
    @Binding var favoritesOnly: Bool
    @Binding var originFilter: LibraryOriginFilter

    var body: some View {
        Section {
            Toggle(isOn: compactBinding) {
                Label("Compact View", systemImage: "rectangle.compress.vertical")
            }
        }

        Section {
            Toggle(isOn: $favoritesOnly) {
                Label("Favorites Only", systemImage: "star")
            }
        }

        Section("Show") {
            Picker("Show", selection: $originFilter) {
                ForEach(LibraryOriginFilter.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option)
                }
            }
            .pickerStyle(.inline)
        }

        Section("Sort By") {
            Picker("Sort By", selection: $sort) {
                ForEach(LibrarySort.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option)
                }
            }
            .pickerStyle(.inline)
        }
    }

    private var compactBinding: Binding<Bool> {
        Binding(
            get: { layout == .compact },
            set: { layout = $0 ? .compact : .normal }
        )
    }
}

/// The library options menu's toolbar label.
struct LibraryOptionsLabel: View {
    static let systemImage = "line.3.horizontal.decrease"

    var body: some View {
        Label("View Options", systemImage: Self.systemImage)
    }
}

/// Enters select mode.
struct SelectButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Select", systemImage: "checkmark.circle")
        }
    }
}

/// Select All / Deselect All while in select mode.
struct SelectAllButton: View {
    let allSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(allSelected ? "Deselect All" : "Select All",
                  systemImage: allSelected ? "checklist.unchecked" : "checklist.checked")
        }
    }
}
