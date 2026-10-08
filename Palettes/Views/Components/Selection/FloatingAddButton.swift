//
//  FloatingAddButton.swift
//  Palettes
//

import SwiftUI

/// Prominent circular add button that floats at the bottom-trailing corner,
/// above the tab bar. Used on the Palettes and Colors tabs in place of a
/// toolbar "+".
struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .glassButton()
        .buttonBorderShape(.circle)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
        .accessibilityLabel("Add")
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Color(.systemBackground)
        FloatingAddButton {}
            .padding(20)
    }
}
