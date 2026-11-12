//
//  CopyButton.swift
//  PalettesWidgets
//
//  The copy glyph on palette and colour widgets. Opens Palettes, which
//  copies and shows its toast (iOS blocked silent copy; see the spec).
//

import SwiftUI
import WidgetKit

struct CopyButton: View {
    /// `.copyPalette(id)` or `.copyColor(id)`.
    let link: WidgetLink
    let onLight: Bool

    var body: some View {
        Link(destination: link.url) {
            GlassCircle(symbol: "doc.on.doc", onLight: onLight)
        }
        .accessibilityLabel("Copy")
    }

    /// Small widgets have one tap target, so a separate copy link can't
    /// work there.
    static func isAvailable(in family: WidgetFamily) -> Bool { family != .systemSmall }
}
