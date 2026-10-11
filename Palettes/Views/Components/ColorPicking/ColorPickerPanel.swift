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
    /// Height of the area under the mode switch, for hosts with a fixed budget
    /// (the palette add panel). Spectrum and Scan shrink to fit; the grid scales
    /// down (and drops "Your Colors"). Nil keeps the natural sizes.
    var contentHeight: CGFloat?
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

    private var areaHeight: CGFloat { contentHeight ?? (compact ? 180 : 220) }

    /// The Spectrum field leaves room for its saturation track (12 + 28 pt).
    private var spectrumHeight: CGFloat {
        contentHeight.map { max($0 - 40, 60) } ?? (compact ? 180 : 220)
    }

    var body: some View {
        VStack(spacing: contentHeight == nil ? 14 : 8) {
            Picker("Picker mode", selection: Binding(get: { mode.rawValue }, set: { modeRaw = $0 })) {
                ForEach(modes) { Text($0.title).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)

            ZStack(alignment: .top) {
                Group {
                    switch mode {
                    case .spectrum: SpectrumPad(color: $color, height: spectrumHeight, onPick: onPick)
                    case .grid:
                        if let contentHeight {
                            SwatchGridPicker(color: $color, showsRecents: false, onPick: onPick)
                                .frame(maxWidth: .infinity, maxHeight: contentHeight, alignment: .top)
                        } else {
                            SwatchGridPicker(color: $color, onPick: onPick)
                        }
                    case .sliders: RGBSliders(color: $color, onPick: onPick)
                    case .scan: ScanPicker(color: $color, session: scanSession ?? localScanSession, height: areaHeight, onPick: onPick)
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
