//
//  GenerationSwatchRow.swift
//  Palettes
//
//  The row of circles under the orb while a palette is made, shared by
//  onboarding and Generate. One slot per expected color; each fills with its
//  color as it arrives.
//

import SwiftUI

struct GenerationSwatchRow: View {
    var colors: [Color]
    /// Slots shown before every color has arrived.
    var expected: Int
    var maxSize: CGFloat = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var slots: Int { max(expected, colors.count) }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<slots, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.04))
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1.5)
                    if index < colors.count {
                        Circle()
                            .fill(colors[index])
                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: maxSize)
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.7), value: colors.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Palette colors")
        .accessibilityValue("\(colors.count) of \(slots)")
    }
}

#Preview {
    GenerationSwatchRow(colors: [.orange, .pink], expected: 5)
        .padding()
}
