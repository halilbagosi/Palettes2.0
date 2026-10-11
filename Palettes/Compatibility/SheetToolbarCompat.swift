//
//  SheetToolbarCompat.swift
//  Palettes
//
//  The cancel and confirm buttons of a creation/edit sheet. iOS 26 uses the
//  system's glass ✕ and ✓ (as Apple's own sheets do); earlier systems use the
//  classic "Cancel" and bold "Add"/"Save" text buttons. The glass buttons are
//  titled `Label`s so they can sit in iPhone Duo's vertical bars (plan 016, A5).
//

import SwiftUI

struct SheetCancelButton: View {
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel, action: action) {
                Label("Cancel", systemImage: "xmark")
            }
        } else {
            Button("Cancel", role: .cancel, action: action)
        }
    }
}

struct SheetConfirmButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Label(title, systemImage: "checkmark")
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(title, action: action)
                .fontWeight(.semibold)
        }
    }
}
