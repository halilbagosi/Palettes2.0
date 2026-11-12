//
//  CopyButton.swift
//  PalettesWidgets
//
//  The copy glyph on palette and colour widgets. Display-only until the
//  copy spike decides how it acts (Task 11 of the widgets plan).
//

import SwiftUI

enum CopyTarget {
    case palette(id: UUID, hexCodes: [String])
    case color(id: UUID, hex: String)

    var id: UUID {
        switch self {
        case .palette(let id, _), .color(let id, _): id
        }
    }
}

struct CopyButton: View {
    let target: CopyTarget
    let onLight: Bool
    /// Just copied: show a checkmark.
    var copied: Bool = false

    var body: some View {
        GlassCircle(symbol: copied ? "checkmark" : "doc.on.doc", onLight: onLight)
    }
}
