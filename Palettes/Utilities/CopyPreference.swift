//
//  CopyPreference.swift
//  Palettes
//
//  What a one-tap copy puts on the clipboard. The first tap asks (see
//  `QuickCopy`), the answer is remembered here, and Settings can change it or
//  clear it so the app asks again. Explicit "Copy as HEX / RGB" menu items
//  don't use this: they always copy what they say.
//

import SwiftUI

enum ColorCopyFormat: String, CaseIterable, Identifiable {
    case hex, rgb

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hex: return "HEX"
        case .rgb: return "RGB"
        }
    }
}

enum PaletteCopyFormat: String, CaseIterable, Identifiable {
    case hex, rgb, css, scss, swiftui, tailwind, json, coolorsURL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hex: return "HEX"
        case .rgb: return "RGB"
        case .css: return "CSS"
        case .scss: return "SCSS"
        case .swiftui: return "SwiftUI"
        case .tailwind: return "Tailwind"
        case .json: return "JSON"
        case .coolorsURL: return "Coolors URL"
        }
    }

    /// The exporter format behind the formats that are exports (HEX and RGB
    /// are the same strings the "Copy as" menu items build).
    fileprivate var exportFormat: PaletteExportFormat? {
        switch self {
        case .hex, .rgb: return nil
        case .css: return .css
        case .scss: return .scss
        case .swiftui: return .swiftui
        case .tailwind: return .tailwind
        case .json: return .json
        case .coolorsURL: return .coolorsURL
        }
    }
}

enum CopyPreference {
    /// App-group defaults, the same suite the widget snapshot lives in. Falls
    /// back to standard defaults where the group isn't available (tests).
    static let sharedDefaults: UserDefaults =
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID) ?? .standard

    static let colorKey = "copyFormat.color"
    static let paletteKey = "copyFormat.palette"

    // MARK: - Stored choice (nil = not chosen yet)

    static func colorFormat(in defaults: UserDefaults = sharedDefaults) -> ColorCopyFormat? {
        defaults.string(forKey: colorKey).flatMap(ColorCopyFormat.init(rawValue:))
    }

    static func setColorFormat(_ format: ColorCopyFormat?, in defaults: UserDefaults = sharedDefaults) {
        set(format?.rawValue, forKey: colorKey, in: defaults)
    }

    static func paletteFormat(in defaults: UserDefaults = sharedDefaults) -> PaletteCopyFormat? {
        defaults.string(forKey: paletteKey).flatMap(PaletteCopyFormat.init(rawValue:))
    }

    static func setPaletteFormat(_ format: PaletteCopyFormat?, in defaults: UserDefaults = sharedDefaults) {
        set(format?.rawValue, forKey: paletteKey, in: defaults)
    }

    private static func set(_ value: String?, forKey key: String, in defaults: UserDefaults) {
        if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
    }

    // MARK: - Text

    /// Same strings as the "Copy as HEX / RGB" menu items.
    static func text(hex: String, color: Color, as format: ColorCopyFormat) -> String {
        switch format {
        case .hex: return hex
        case .rgb: return color.rgbString
        }
    }

    static func text(for palette: PaletteViewModel, as format: PaletteCopyFormat) -> String {
        switch format {
        case .hex:
            return palette.hexCodes.joined(separator: ", ")
        case .rgb:
            return palette.colors.map { $0.rgbString }.joined(separator: " | ")
        default:
            return PaletteExporter.export(palette, as: format.exportFormat ?? .plainHex)
        }
    }

    /// What a widget's copy link copies: the saved format, or HEX (the in-app HEX text) if
    /// the user hasn't picked one (a widget tap can't ask).
    static func widgetColorText(hex: String, color: Color, in defaults: UserDefaults = sharedDefaults) -> (text: String, label: String) {
        let format = colorFormat(in: defaults) ?? .hex
        return (text(hex: hex, color: color, as: format), "Copied \(format.displayName)")
    }

    static func widgetPaletteText(_ palette: PaletteViewModel, in defaults: UserDefaults = sharedDefaults) -> (text: String, label: String) {
        let format = paletteFormat(in: defaults) ?? .hex
        return (text(for: palette, as: format), "Copied \(format.displayName)")
    }
}

// MARK: - One-tap copy

/// A one-tap copy waiting on (or about to use) the saved format.
enum QuickCopyRequest: Identifiable {
    case color(hex: String, color: Color)
    /// Carries only the id: cards compare equal while names and roles change,
    /// so the live palette is looked up when the copy actually runs.
    case palette(id: UUID)

    var id: String {
        switch self {
        case .color(let hex, _): return "color-\(hex)"
        case .palette(let id): return "palette-\(id)"
        }
    }
}

@MainActor
enum QuickCopy {
    /// Copies with the saved format, or, if none is saved for this kind,
    /// parks the request in `ask` so `quickCopyDialog` can ask first.
    static func perform(_ request: QuickCopyRequest, appData: AppData, ask: Binding<QuickCopyRequest?>) {
        switch request {
        case .color(let hex, let color):
            if let format = CopyPreference.colorFormat() {
                copyToClipboard(CopyPreference.text(hex: hex, color: color, as: format), label: "Copied \(format.displayName)")
            } else {
                ask.wrappedValue = request
            }
        case .palette(let id):
            guard let palette = appData.palettes.first(where: { $0.id == id }) else { return }
            if let format = CopyPreference.paletteFormat() {
                copyToClipboard(CopyPreference.text(for: palette, as: format), label: "Copied \(format.displayName)")
            } else {
                ask.wrappedValue = request
            }
        }
    }
}

private struct QuickCopyDialog: ViewModifier {
    @Binding var request: QuickCopyRequest?
    @EnvironmentObject private var appData: AppData

    func body(content: Content) -> some View {
        // An alert, not a confirmation dialog: a dialog anchors to the
        // tapped button (a popover on iPad and iOS 26), the alert is centered.
        content.alert(
            "Choose what Copy copies",
            isPresented: Binding(
                get: { request != nil },
                set: { if !$0 { request = nil } }
            ),
            presenting: request
        ) { pending in
            switch pending {
            case .color(let hex, let color):
                ForEach(ColorCopyFormat.allCases) { format in
                    Button(format.displayName) {
                        CopyPreference.setColorFormat(format)
                        copyToClipboard(CopyPreference.text(hex: hex, color: color, as: format), label: "Copied \(format.displayName)")
                    }
                }
            case .palette(let id):
                ForEach(PaletteCopyFormat.allCases) { format in
                    Button(format.displayName) {
                        CopyPreference.setPaletteFormat(format)
                        guard let palette = appData.palettes.first(where: { $0.id == id }) else { return }
                        copyToClipboard(CopyPreference.text(for: palette, as: format), label: "Copied \(format.displayName)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You can change this later in Settings.")
        }
    }
}

extension View {
    /// Attach once per screen that has one-tap copy buttons; they hand
    /// `QuickCopy.perform` the same binding.
    func quickCopyDialog(_ request: Binding<QuickCopyRequest?>) -> some View {
        modifier(QuickCopyDialog(request: request))
    }
}
