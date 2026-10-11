import SwiftUI

enum ColorPickerMode: String, CaseIterable, Identifiable {
    case spectrum, grid, sliders
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spectrum: "Spectrum"
        case .grid: "Grid"
        case .sliders: "Sliders"
        }
    }
}

/// The always-visible picker: Spectrum, Grid or Sliders — the same three
/// modes as Apple's color picker, so it reads as familiar.
struct ColorPickerPanel: View {
    @Binding var color: Color
    var compact = true
    var onPick: (Color) -> Void

    @AppStorage("colorPickerMode") private var modeRaw = ColorPickerMode.spectrum.rawValue
    private var mode: ColorPickerMode { ColorPickerMode(rawValue: modeRaw) ?? .spectrum }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Picker", selection: $modeRaw) {
                ForEach(ColorPickerMode.allCases) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)

            Group {
                switch mode {
                case .spectrum: SpectrumPad(color: $color, height: compact ? 180 : 220, onPick: onPick)
                case .grid: SwatchGridPicker(color: $color, onPick: onPick)
                case .sliders: RGBSliders(color: $color, onPick: onPick)
                }
            }
            .transition(.opacity)
        }
        .animation(.snappy, value: modeRaw)
    }
}

#Preview {
    ColorPickerPanel(color: .constant(.orange), onPick: { _ in })
        .padding()
        .environmentObject(AppData(inMemory: true))
}
