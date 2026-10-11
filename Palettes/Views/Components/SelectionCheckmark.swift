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
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: isSelected)
            .accessibilityLabel(isSelected ? "Selected" : "Not selected")
    }
}

/// Select-mode chrome shared by the library cards: a checkmark badge that pops
/// in, an accent outline, a slight press-in when selected, and a full-card tap
/// target that toggles selection.
struct SelectableCardChrome: ViewModifier {
    let isSelecting: Bool
    let isSelected: Bool
    var cornerRadius: CGFloat = 28
    let onToggle: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    SelectionCheckmark(isSelected: isSelected)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .opacity(isSelecting && isSelected ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay {
                if isSelecting {
                    Color.white.opacity(0.001)
                        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .onTapGesture(perform: onToggle)
                }
            }
            .scaleEffect(isSelecting && isSelected ? 0.965 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: isSelected)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelecting)
    }
}

extension View {
    func selectableCardChrome(isSelecting: Bool, isSelected: Bool, onToggle: @escaping () -> Void) -> some View {
        modifier(SelectableCardChrome(isSelecting: isSelecting, isSelected: isSelected, onToggle: onToggle))
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
