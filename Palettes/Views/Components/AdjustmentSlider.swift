//
//  AdjustmentSlider.swift
//  Palettes
//

import SwiftUI

/// A titled 0…1 slider with a live value label and captions at both ends.
struct AdjustmentSlider: View {
    let title: String
    let valueLabel: String
    let leftLabel: String
    let rightLabel: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                Spacer()
                Text(valueLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            Slider(value: $value)
                .tint(.accentColor)
                .accessibilityLabel(title)
                .accessibilityValue(valueLabel)
                .accessibilityHint("Adjusts from \(leftLabel) to \(rightLabel)")
            HStack {
                Text(leftLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text(rightLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .accessibilityHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var value = 0.5
    return AdjustmentSlider(
        title: "Temperature",
        valueLabel: "Neutral",
        leftLabel: "Cool",
        rightLabel: "Warm",
        value: $value
    )
    .padding()
}
