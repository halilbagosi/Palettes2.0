//
//  MorphingCardGrid.swift
//  Palettes
//
//  A non-lazy adaptive grid (like `LazyVGrid(.adaptive)`) whose column metrics
//  and row height are plain stored properties. Because it is a `Layout`, changing
//  any of them inside `withAnimation` makes every card travel from its old frame
//  to its new one — position *and* size — which is what produces the smooth morph
//  between the library's normal and compact layouts. Rows share a uniform height.
//
//  Trade-off: unlike `LazyVGrid`, a `Layout` measures every subview, so this is
//  non-lazy. That is fine for the curated colour/palette libraries here; it would
//  need revisiting for collections of many hundreds of items.
//

import SwiftUI

struct MorphingCardGrid: Layout {
    /// Minimum width a column may shrink to before the count drops (matches the
    /// `.adaptive(minimum:)` behaviour of the grids this replaces).
    var minColumnWidth: CGFloat
    /// Column width is capped here so cards don't stretch absurdly wide on iPad.
    var maxColumnWidth: CGFloat
    /// Uniform height for every row in the current layout mode.
    var rowHeight: CGFloat
    /// Gap between columns and rows.
    var spacing: CGFloat

    private func columnCount(forWidth width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }

    private func columnWidth(forWidth width: CGFloat, count: Int) -> CGFloat {
        let totalSpacing = spacing * CGFloat(count - 1)
        let raw = (width - totalSpacing) / CGFloat(count)
        return min(raw, maxColumnWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let count = columnCount(forWidth: width)
        let rows = Int(ceil(Double(subviews.count) / Double(count)))
        let height = CGFloat(rows) * rowHeight + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = columnCount(forWidth: bounds.width)
        let colWidth = columnWidth(forWidth: bounds.width, count: count)
        let contentWidth = CGFloat(count) * colWidth + CGFloat(count - 1) * spacing
        let startX = bounds.minX + max(0, (bounds.width - contentWidth) / 2)
        let sizeProposal = ProposedViewSize(width: colWidth, height: rowHeight)

        for (index, subview) in subviews.enumerated() {
            let row = index / count
            let col = index % count
            let x = startX + CGFloat(col) * (colWidth + spacing)
            let y = bounds.minY + CGFloat(row) * (rowHeight + spacing)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: sizeProposal)
        }
    }
}
