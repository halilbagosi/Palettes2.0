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

/// Hue, saturation and brightness sliders on a glass card, plus the system
/// picker for its eyedropper and spectrum. Every change is reported through
/// `onChange`; outside changes to `color` (typed values, the system picker)
/// move the sliders without fighting a drag in progress.
struct HSBSlidersCard: View {
    let color: Color
    var onChange: (Color) -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0
    /// Hex of the last color these sliders produced (or synced from), so their
    /// own changes coming back through `color` don't re-derive the sliders.
    @State private var syncedHex = ""

    private static let spectrum: [Color] = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
        Color(hue: $0, saturation: 0.9, brightness: 1)
    }

    var body: some View {
        VStack(spacing: 18) {
            GradientSlider(
                title: "Hue",
                valueLabel: "\(Int(round(hue * 360)))°",
                gradient: Self.spectrum,
                thumbColor: color,
                value: emitting($hue)
            )
            GradientSlider(
                title: "Saturation",
                valueLabel: "\(Int(round(saturation * 100)))%",
                gradient: [
                    Color(hue: hue, saturation: 0, brightness: max(brightness, 0.3)),
                    Color(hue: hue, saturation: 1, brightness: max(brightness, 0.3))
                ],
                thumbColor: color,
                value: emitting($saturation)
            )
            GradientSlider(
                title: "Brightness",
                valueLabel: "\(Int(round(brightness * 100)))%",
                gradient: [.black, Color(hue: hue, saturation: saturation, brightness: 1)],
                thumbColor: color,
                value: emitting($brightness)
            )

            Divider()

            ColorPicker(
                selection: Binding(get: { color }, set: { onChange($0) }),
                supportsOpacity: false
            ) {
                Label("Eyedropper & Spectrum", systemImage: "eyedropper")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(16)
        .liquidGlass(.regular, in: .rect(cornerRadius: 20))
        .onAppear { sync(from: color) }
        .onChange(of: ColorAdjustment.hexString(from: color)) { _, hex in
            if hex != syncedHex { sync(from: color) }
        }
    }

    private func emitting(_ component: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { component.wrappedValue },
            set: { newValue in
                component.wrappedValue = newValue
                let newColor = Color(hue: hue, saturation: saturation, brightness: brightness)
                syncedHex = ColorAdjustment.hexString(from: newColor)
                onChange(newColor)
            }
        )
    }

    private func sync(from color: Color) {
        let hsb = color.hsbComponents
        // Hue is undefined for grays and saturation for black: keep the old
        // values there so the thumbs don't jump to zero.
        if hsb.b > 0.001 {
            if hsb.s > 0.001 { hue = hsb.h }
            saturation = hsb.s
        }
        brightness = hsb.b
        syncedHex = ColorAdjustment.hexString(from: color)
    }
}

#Preview {
    @Previewable @State var color = Color.orange
    return HSBSlidersCard(color: color) { color = $0 }
        .padding()
}
