//
//  FloatingAddButton.swift
//  Palettes
//

import SwiftUI

/// Prominent circular add button that floats at the bottom-trailing corner,
/// above the tab bar. Used on the Palettes and Colors tabs in place of a
/// toolbar "+".
struct FloatingAddButton: View {
    /// Spoken by VoiceOver, and the pointer tooltip on iPad.
    var title: String = "Add"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .modifier(FloatingAddStyle())
        .buttonBorderShape(.circle)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
        .accessibilityLabel(title)
        .help(title)
    }
}

/// iOS 26: glass. Earlier: an opaque accent-filled circle with a white glyph —
/// `.bordered` is translucent, so content scrolling underneath showed through
/// the "+" and made it unreadable.
private struct FloatingAddStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        Color(.systemBackground)
        FloatingAddButton {}
            .padding(20)
    }
}
