//
//  WidgetCopyText.swift
//  Palettes (app + widgets)
//
//  What a widget's copy button puts on the clipboard. Must match the app:
//  colours copy their hex; palettes copy the Plain HEX export.
//

import Foundation

nonisolated enum WidgetCopyText {
    /// Same as `PaletteExporter.export(_, as: .plainHex)`.
    static func palette(_ hexCodes: [String]) -> String {
        hexCodes.joined(separator: "\n")
    }

    static func color(_ hex: String) -> String { hex }
}
