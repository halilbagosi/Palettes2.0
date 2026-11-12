//
//  CopyButton.swift
//  PalettesWidgets
//
//  The copy glyph on palette and colour widgets. Opens Palettes, which
//  copies and shows its toast (iOS blocked silent copy; see the spec).
//

import SwiftUI
import WidgetKit

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
        Link(destination: link.url) {
            GlassCircle(symbol: "doc.on.doc", onLight: onLight)
        }
    }

    private var link: WidgetLink {
        switch target {
        case .palette(let id, _): .copyPalette(id)
        case .color(let id, _): .copyColor(id)
        }
    }

    /// Small widgets have one tap target, so a separate copy link can't
    /// work there.
    static func isAvailable(in family: WidgetFamily) -> Bool { family != .systemSmall }
}
