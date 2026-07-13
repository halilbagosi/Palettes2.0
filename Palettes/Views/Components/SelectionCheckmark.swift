//
//  SelectionCheckmark.swift
//  Palettes
//

import SwiftUI

/// Corner badge shown on cells while a list is in multi-select mode.
/// Filled accent check when selected, hollow circle otherwise.
struct SelectionCheckmark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2.weight(.semibold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, isSelected ? Color.accentColor : Color.black.opacity(0.25))
            .padding(12)
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
            .accessibilityLabel(isSelected ? "Selected" : "Not selected")
    }
}

#Preview {
    HStack(spacing: 20) {
        SelectionCheckmark(isSelected: true)
        SelectionCheckmark(isSelected: false)
    }
    .padding()
    .background(Color.gray)
}
