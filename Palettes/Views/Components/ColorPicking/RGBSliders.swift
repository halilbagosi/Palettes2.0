import SwiftUI

/// Red, green and blue as absolute 0–255 sliders. Each track shows that
/// channel's range at the current other channels; nothing ever recenters.
struct RGBSliders: View {
    @Binding var color: Color
    var onPick: (Color) -> Void

    private enum Channel: Int, CaseIterable {
        case red, green, blue

        var letter: String {
            switch self {
            case .red: "R"
            case .green: "G"
            case .blue: "B"
            }
        }

        var name: String {
            switch self {
            case .red: "Red"
            case .green: "Green"
            case .blue: "Blue"
            }
        }
    }

    var body: some View {
        let rgb = color.rgbComponents
        let values = [rgb.r, rgb.g, rgb.b].map { min(max($0.rounded(), 0), 255) }
        VStack(spacing: 14) {
            ForEach(Channel.allCases, id: \.rawValue) { channel in
                row(channel, values: values)
            }
        }
    }

    private func row(_ channel: Channel, values: [Double]) -> some View {
        let value = values[channel.rawValue]
        let lo = low(channel, values)
        let hi = high(channel, values)
        return HStack(spacing: 12) {
            Text(channel.letter)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            ZStack {
                Capsule()
                    .fill(LinearGradient(
                        colors: [ColorAdjustment.color(r: lo.0, g: lo.1, b: lo.2),
                                 ColorAdjustment.color(r: hi.0, g: hi.1, b: hi.2)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                Slider(
                    value: Binding(
                        get: { value },
                        set: { write($0, to: channel, values: values) }
                    ),
                    in: 0...255, step: 1
                )
                .tint(.clear)
                .accessibilityLabel(channel.name)
                .accessibilityValue("\(Int(value))")
            }
            Text("\(Int(value))")
                .font(.body.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private func low(_ channel: Channel, _ v: [Double]) -> (Double, Double, Double) {
        var out = (v[0], v[1], v[2])
        switch channel {
        case .red: out.0 = 0
        case .green: out.1 = 0
        case .blue: out.2 = 0
        }
        return out
    }

    private func high(_ channel: Channel, _ v: [Double]) -> (Double, Double, Double) {
        var out = (v[0], v[1], v[2])
        switch channel {
        case .red: out.0 = 255
        case .green: out.1 = 255
        case .blue: out.2 = 255
        }
        return out
    }

    private func write(_ newValue: Double, to channel: Channel, values: [Double]) {
        var v = values
        v[channel.rawValue] = newValue
        let new = ColorAdjustment.color(r: v[0], g: v[1], b: v[2])
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { onPick(new) }
    }
}
