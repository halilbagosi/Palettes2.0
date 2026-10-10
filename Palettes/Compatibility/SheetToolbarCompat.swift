//
//  SheetToolbarCompat.swift
//  Palettes
//
//  The cancel and confirm buttons of a creation/edit sheet. iOS 26 uses the
//  system's glass ✕ and ✓ (as Apple's own sheets do); earlier systems use the
//  classic "Cancel" and bold "Add"/"Save" text buttons. Either way the
//  accessibility label carries the action's name.
//

import SwiftUI

struct SheetCancelButton: View {
    var action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(role: .cancel, action: action) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Cancel")
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
                Image(systemName: "checkmark")
            }
            .buttonStyle(.glassProminent)
            .accessibilityLabel(title)
        } else {
            Button(title, action: action)
                .fontWeight(.semibold)
        }
    }
}
