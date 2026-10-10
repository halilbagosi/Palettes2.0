//
//  GradientSlider.swift
//  Palettes
//

import SwiftUI

/// A 0…1 slider whose track is the gradient it selects from (the hue
/// spectrum, a saturation ramp, …) and whose thumb wears the current color.
struct GradientSlider: View {
    let title: String
    let valueLabel: String
    let gradient: [Color]
    let thumbColor: Color
    @Binding var value: Double

    @State private var isDragging = false

    private let trackHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueLabel)
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            GeometryReader { proxy in
                let travel = max(proxy.size.width - trackHeight, 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))

                    Circle()
                        .fill(thumbColor)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .frame(width: trackHeight, height: trackHeight)
                        .scaleEffect(isDragging ? 1.15 : 1)
                        .offset(x: CGFloat(value) * travel)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            let x = drag.location.x - trackHeight / 2
                            value = min(max(Double(x / travel), 0), 1)
                        }
                        .onEnded { _ in isDragging = false }
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            }
            .frame(height: trackHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(valueLabel)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: value = min(value + 0.05, 1)
                case .decrement: value = max(value - 0.05, 0)
                @unknown default: break
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var value = 0.4
    return GradientSlider(
        title: "Hue",
        valueLabel: "\(Int(value * 360))°",
        gradient: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
        thumbColor: Color(hue: value, saturation: 0.9, brightness: 1),
        value: $value
    )
    .padding()
}
