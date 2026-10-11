import SwiftUI

enum ColorPickerMode: String, CaseIterable, Identifiable {
    case spectrum, grid, sliders, scan
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spectrum: "Spectrum"
        case .grid: "Grid"
        case .sliders: "Sliders"
        case .scan: "Scan"
        }
    }
}

/// The always-visible picker: Spectrum, Grid or Sliders — the same three
/// modes as Apple's color picker, so it reads as familiar — plus Scan (pick
/// from a photo) where the host allows it.
struct ColorPickerPanel: View {
    @Binding var color: Color
    var compact = true
    /// Offers the Scan mode. Off by default; the stored mode falls back to
    /// Spectrum where it's off.
    var allowsScan = false
    /// Where Scan keeps its photo. A host that can remove this panel (e.g. while
    /// the keyboard is up) passes its own so the photo survives; otherwise the
    /// panel keeps one for as long as it lives.
    var scanSession: ScanSession?
    var onPick: (Color) -> Void

    @AppStorage("colorPickerMode") private var modeRaw = ColorPickerMode.spectrum.rawValue
    @StateObject private var localScanSession = ScanSession()

    private var mode: ColorPickerMode {
        let stored = ColorPickerMode(rawValue: modeRaw) ?? .spectrum
        return stored == .scan && !allowsScan ? .spectrum : stored
    }

    private var modes: [ColorPickerMode] {
        ColorPickerMode.allCases.filter { $0 != .scan || allowsScan }
    }

    var body: some View {
        VStack(spacing: 14) {
            Picker("Picker mode", selection: Binding(get: { mode.rawValue }, set: { modeRaw = $0 })) {
                ForEach(modes) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .top) {
                Group {
                    switch mode {
                    case .spectrum: SpectrumPad(color: $color, height: compact ? 180 : 220, onPick: onPick)
                    case .grid: SwatchGridPicker(color: $color, onPick: onPick)
                    case .sliders: RGBSliders(color: $color, onPick: onPick)
                    case .scan: ScanPicker(color: $color, session: scanSession ?? localScanSession, height: compact ? 180 : 220, onPick: onPick)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: mode)
    }
}

#Preview {
    ColorPickerPanel(color: .constant(.orange), onPick: { _ in })
        .padding()
        .environmentObject(AppData(inMemory: true))
}
