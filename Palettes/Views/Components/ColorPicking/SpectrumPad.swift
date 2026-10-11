import SwiftUI

/// Hue across, brightness down, saturation on its own track below. Drags
/// follow the finger exactly — no animation — so the swatch above answers
/// as the finger moves.
struct SpectrumPad: View {
    @Binding var color: Color
    var height: CGFloat = 180
    var onPick: (Color) -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var lastHex = ""
    /// True while a finger is on the field / the saturation track; the thumb
    /// grows under it so it isn't hidden by the fingertip.
    @GestureState private var fieldTouched = false
    @GestureState private var saturationTouched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let minBrightness = 0.15

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Only the gradients are clipped; the thumb overlays unclipped
                    // so it isn't cut off at the field's edges.
                    ZStack {
                        LinearGradient(
                            colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map { Color(hue: $0, saturation: fieldSaturation, brightness: 1) },
                            startPoint: .leading, endPoint: .trailing
                        )
                        LinearGradient(colors: [.clear, .black.opacity(1 - Self.minBrightness)], startPoint: .top, endPoint: .bottom)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    thumb(touched: fieldTouched).position(x: hue * geo.size.width, y: (1 - (brightness - Self.minBrightness) / (1 - Self.minBrightness)) * geo.size.height)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($fieldTouched) { _, touched, _ in touched = true }
                    .onChanged { value in
                    let x = min(max(value.location.x / geo.size.width, 0), 1)
                    let y = min(max(value.location.y / geo.size.height, 0), 1)
                    // The field is drawn vivid for grays; adopt that saturation so
                    // the picked color matches what's under the finger.
                    if saturation < 0.05 { saturation = 0.5 }
                    set(hue: x, brightness: 1 - y * (1 - Self.minBrightness))
                })
            }
            .frame(height: height)
            .accessibilityElement()
            .accessibilityLabel("Color field")
            .accessibilityValue("Hue \(Int(hue * 360)) degrees, brightness \(Int(brightness * 100)) percent")
            .accessibilityAdjustableAction { direction in
                let step = direction == .increment ? 1.0 / 36 : -1.0 / 36
                set(hue: (hue + step + 1).truncatingRemainder(dividingBy: 1), brightness: brightness)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LinearGradient(
                        colors: [Color(hue: hue, saturation: 0, brightness: brightness), Color(hue: hue, saturation: 1, brightness: brightness)],
                        startPoint: .leading, endPoint: .trailing))
                    thumb(touched: saturationTouched).position(x: saturation * geo.size.width, y: geo.size.height / 2)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($saturationTouched) { _, touched, _ in touched = true }
                    .onChanged { value in
                    saturation = min(max(value.location.x / geo.size.width, 0), 1)
                    commit()
                })
            }
            .frame(height: 28)
            .accessibilityElement()
            .accessibilityLabel("Saturation")
            .accessibilityValue("\(Int(saturation * 100)) percent")
            .accessibilityAdjustableAction { direction in
                saturation = min(max(saturation + (direction == .increment ? 0.05 : -0.05), 0), 1)
                commit()
            }
        }
        .onAppear { read(color) }
        .onChange(of: ColorComposer.hexKey(color)) { _, hex in
            if hex != lastHex { read(color) }
        }
    }

    /// True grays (saturation < 0.05) are drawn at 0.5 so the field never turns
    /// into a gray slab; touching the field adopts that saturation. Pastels stay exact.
    private var fieldSaturation: Double { saturation < 0.05 ? 0.5 : saturation }

    /// 24 pt at rest, 32 pt under a finger (no size change with Reduce Motion).
    /// Only the size animates; the position is set outside this view and
    /// follows the finger 1:1.
    private func thumb(touched: Bool) -> some View {
        let size: CGFloat = touched && !reduceMotion ? 32 : 24
        return Circle()
            .strokeBorder(.white, lineWidth: 2)
            .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: brightness)))
            .frame(width: size, height: size)
            .animation(.spring(duration: 0.2, bounce: 0), value: size)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .allowsHitTesting(false)
    }

    private func set(hue: Double, brightness: Double) {
        self.hue = hue
        self.brightness = brightness
        commit()
    }

    private func commit() {
        let new = Color(hue: hue, saturation: saturation, brightness: brightness)
        lastHex = ColorComposer.hexKey(new)
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { onPick(new) }
    }

    /// Reads an outside change. Gray has no hue, so keep the last hue rather
    /// than snapping the thumb to red.
    private func read(_ color: Color) {
        let hsb = color.hsbComponents
        if hsb.s > 0.01 { hue = hsb.h }
        saturation = hsb.s
        brightness = max(hsb.b, Self.minBrightness)
        lastHex = ColorComposer.hexKey(color)
    }
}
