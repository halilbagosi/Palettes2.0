//
//  CopyOrEdit.swift
//  Palettes
//
//  The HEX and RGB value fields' gesture, shared by the add panel's Pick
//  source and Edit Color.
//

import SwiftUI

extension View {
    /// A value field that opens for typing on tap and copies on press and
    /// hold. While it is being edited, touches go to the text field itself.
    func copyOrEdit(isEditing: Bool, copy: @escaping () -> Void, edit: @escaping () -> Void) -> some View {
        contentShape(Rectangle())
            .onTapGesture {
                if !isEditing { edit() }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                if !isEditing { copy() }
            }
            .accessibilityHint("Double-tap to type a value. Use the Copy action to copy it.")
            .accessibilityAction(named: "Copy", copy)
            .accessibilityAction(named: "Edit", edit)
    }
}

/// The help line under the HEX and RGB fields.
enum ValuesHelp {
    static let text = "Tap a value to edit it \u{00B7} press and hold to copy"
}

/// The HEX, R, G and B fields in one row: HEX a little wider than each
/// channel (`hexWeight` shares to their one), and never narrower than it
/// needs to show six characters.
struct ValuesRow: Layout {
    var spacing: CGFloat = 6
    var hexWeight: CGFloat = 1.5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = columnWidths(total: proposal.width, subviews: subviews)
        let height = zip(subviews, widths)
            .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height }
            .max() ?? 0
        return CGSize(width: widths.reduce(0, +) + spacing * CGFloat(max(subviews.count - 1, 0)), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, columnWidths(total: bounds.width, subviews: subviews)) {
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }

    /// The first subview is HEX; the rest share what's left equally.
    private func columnWidths(total: CGFloat?, subviews: Subviews) -> [CGFloat] {
        guard let first = subviews.first else { return [] }
        let channels = CGFloat(subviews.count - 1)
        let hexIdeal = first.sizeThatFits(.unspecified).width
        guard let total else {
            return [hexIdeal] + subviews.dropFirst().map { $0.sizeThatFits(.unspecified).width }
        }
        let available = max(total - spacing * channels, 0)
        let hex = max(available * hexWeight / (hexWeight + channels), min(hexIdeal, available))
        let channel = channels > 0 ? max(available - hex, 0) / channels : 0
        return [hex] + Array(repeating: channel, count: Int(channels))
    }
}
