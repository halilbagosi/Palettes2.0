//
//  SheetToolbarCompat.swift
//  Palettes
//
//  The cancel and confirm buttons of a creation/edit sheet, identical in shape
//  on every iOS version. The rule: Cancel is an ✕; a sheet that *creates* or
//  *saves* confirms with a ✓; a button that *adds* something shows "+" (and
//  "Add N" once a count is known). iOS 26 renders the glass variants; earlier
//  systems use plain icon buttons. Every item is a titled `Label` so it reads
//  correctly in iPhone Duo's vertical bars (plan 016, A5) and to VoiceOver.
//

import SwiftUI

struct SheetCancelButton: View {
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            // Bare Label: the system picks icon or title (Duo bars, overflow menus).
            Button(role: .cancel, action: action) {
                Label("Cancel", systemImage: "xmark")
            }
        } else {
            Button(role: .cancel, action: action) {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
        }
    }
}

struct SheetConfirmButton: View {
    enum Kind {
        case create, save, add(count: Int? = nil)
    }
    let kind: Kind
    var action: () -> Void

    private var title: String {
        switch kind {
        case .create: "Create"
        case .save: "Save"
        case .add(let count?): "Add \(count)"
        case .add(nil): "Add"
        }
    }

    private var spokenTitle: String {
        if case .add(let count?) = kind, count >= 1 { return "Add \(count) \(count == 1 ? "color" : "colors")" }
        return title
    }

    private var symbol: String {
        if case .add = kind { return "plus" }
        return "checkmark"
    }

    /// "+ Add 3" reads as title and icon; everything else is icon-only.
    private var showsTitle: Bool {
        if case .add(let count?) = kind { return count >= 1 }
        return false
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            // The system decides icon vs. title unless a count makes the title essential.
            Button(action: action) {
                if showsTitle {
                    Label(title, systemImage: symbol)
                        .labelStyle(.titleAndIcon)
                } else {
                    Label(title, systemImage: symbol)
                }
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel(spokenTitle)
        } else {
            Button(action: action) {
                if showsTitle {
                    Label(title, systemImage: symbol)
                        .labelStyle(.titleAndIcon)
                        .fontWeight(.semibold)
                } else {
                    Label(title, systemImage: symbol)
                        .labelStyle(.iconOnly)
                        .fontWeight(.semibold)
                }
            }
            .accessibilityLabel(spokenTitle)
        }
    }
}
