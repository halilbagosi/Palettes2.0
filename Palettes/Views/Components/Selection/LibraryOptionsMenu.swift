//
//  LibraryOptionsMenu.swift
//  Palettes
//
//  Contents of the "•••" toolbar menu shared by the Palettes and Colors
//  libraries. Place inside a `Menu { LibraryOptionsMenu(...) } label: { ... }`.
//

import SwiftUI

struct LibraryOptionsMenu: View {
    @Binding var layout: ListLayout
    @Binding var sort: LibrarySort
    @Binding var favoritesOnly: Bool

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
