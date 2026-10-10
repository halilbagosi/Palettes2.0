//
//  MorphingCardGrid.swift
//  Palettes
//
//  An adaptive grid (like `LazyVGrid(.adaptive)`) whose column metrics and row
//  height are plain stored properties. Because it is a `Layout`, changing any of
//  them inside `withAnimation` makes every card travel from its old frame to its
//  new one — position *and* size — which is what produces the smooth morph
//  between the library's normal and compact layouts. Rows share a uniform height.
//
//  A `Layout` measures every subview, so on its own it is non-lazy. For large
//  libraries use `LazyMorphingCardGrid`, which mounts only the cards near the
//  viewport and tells the layout each card's absolute index.
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
    /// Total number of items when only a window of them is passed as subviews
    /// (each tagged with `MorphingGridIndex`); nil means every item is a subview.
    var itemCount: Int? = nil
    /// The x extent (grid-local) of iPhone Duo's fold while half open in
    /// landscape. The columns then split evenly either side of it, each side
    /// centred in its half, and no card sits on the crease.
    var foldSpan: ClosedRange<CGFloat>? = nil

    /// Column origins (grid-local x) and the shared column width.
    private struct Columns {
        var originXs: [CGFloat]
        var width: CGFloat
        var count: Int { originXs.count }
    }

    func columnCount(forWidth width: CGFloat) -> Int {
        columns(forWidth: width).count
    }

    private func fittingCount(in width: CGFloat) -> Int {
        guard width > 0 else { return 1 }
        return max(1, Int((width + spacing) / (minColumnWidth + spacing)))
    }

    private func columnWidth(forWidth width: CGFloat, count: Int) -> CGFloat {
        let totalSpacing = spacing * CGFloat(count - 1)
        let raw = (width - totalSpacing) / CGFloat(count)
        return min(raw, maxColumnWidth)
    }

    /// `count` columns of `width` centred in `start..<start + available`.
    private func origins(count: Int, width: CGFloat, start: CGFloat, available: CGFloat) -> [CGFloat] {
        let content = CGFloat(count) * width + CGFloat(count - 1) * spacing
        let first = start + max(0, (available - content) / 2)
        return (0..<count).map { first + CGFloat($0) * (width + spacing) }
    }

    private func columns(forWidth width: CGFloat) -> Columns {
        if let fold = foldSpan {
            let leading = fold.lowerBound
            let trailing = width - fold.upperBound
            if leading > 0, trailing > 0 {
                // The same number of columns on each side, sized by the narrower side.
                let side = min(leading, trailing)
                let perSide = fittingCount(in: side)
                let colWidth = max(0, columnWidth(forWidth: side, count: perSide))
                return Columns(
                    originXs: origins(count: perSide, width: colWidth, start: 0, available: leading)
                        + origins(count: perSide, width: colWidth, start: fold.upperBound, available: trailing),
                    width: colWidth
                )
            }
        }
        let count = fittingCount(in: width)
        let colWidth = columnWidth(forWidth: width, count: count)
        return Columns(originXs: origins(count: count, width: colWidth, start: 0, available: width),
                       width: colWidth)
    }

    /// Indices of the items whose rows overlap the vertical span `minY...maxY`.
    func itemRange(fromY minY: CGFloat, toY maxY: CGFloat, width: CGFloat, itemCount: Int) -> Range<Int> {
        let count = columnCount(forWidth: width)
        let rowStride = rowHeight + spacing
        let firstRow = max(0, Int((minY / rowStride).rounded(.down)))
        let lastRow = max(firstRow, Int((maxY / rowStride).rounded(.down)))
        let lower = min(itemCount, firstRow * count)
        let upper = min(itemCount, (lastRow + 1) * count)
        return lower..<upper
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let count = columnCount(forWidth: width)
        let rows = Int(ceil(Double(itemCount ?? subviews.count) / Double(count)))
        let height = CGFloat(rows) * rowHeight + CGFloat(max(0, rows - 1)) * spacing
        return CGSize(width: width, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columns(forWidth: bounds.width)
        let count = columns.count
        let sizeProposal = ProposedViewSize(width: columns.width, height: rowHeight)

        for (offset, subview) in subviews.enumerated() {
            let index = subview[MorphingGridIndex.self] ?? offset
            let row = index / count
            let col = index % count
            let x = bounds.minX + columns.originXs[col]
            let y = bounds.minY + CGFloat(row) * (rowHeight + spacing)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: sizeProposal)
        }
    }
}

/// A subview's absolute position in the full collection, for windowed grids.
nonisolated struct MorphingGridIndex: LayoutValueKey {
    static let defaultValue: Int? = nil
}

/// `MorphingCardGrid` that only mounts cards near the visible part of the
/// enclosing `ScrollView`, so cost scales with the screen, not the library.
///
/// To keep the layout-toggle morph, pass the other configuration(s) the grid
/// can switch to as `morphTargets`: cards that would be on screen under any of
/// them stay mounted, so after a toggle every visible card animates in from its
/// previous frame instead of popping in.
struct LazyMorphingCardGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let grid: MorphingCardGrid
    var morphTargets: [MorphingCardGrid] = []
    @ViewBuilder let content: (Item) -> Content

    /// Visible region of the scroll view in grid-local coordinates, snapped to
    /// `Self.snap` so scrolling only re-renders the grid every few rows.
    @State private var viewport: CGRect = .zero
    /// iPhone Duo's fold across the grid (see `MorphingCardGrid.foldSpan`).
    @State private var foldSpan: ClosedRange<CGFloat>?

    private static var snap: CGFloat { 256 }
    /// Cards mounted before measurement, so the first frame isn't empty.
    private static var initialCount: Int { 24 }

    private struct Slot: Identifiable {
        let index: Int
        let item: Item
        var id: Item.ID { item.id }
    }

    var body: some View {
        var layout = grid
        layout.itemCount = items.count
        layout.foldSpan = foldSpan

        return layout {
            ForEach(mountedSlots) { slot in
                content(slot.item)
                    .layoutValue(key: MorphingGridIndex.self, value: slot.index)
            }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            Self.snappedViewport(proxy)
        } action: { newValue in
            viewport = newValue
        }
        .onGeometryChange(for: ClosedRange<CGFloat>?.self) { proxy in
            proxy.verticalFoldSpan
        } action: { newValue in
            // Cards move and resize to their new columns as the device folds.
            withAnimation(.smooth(duration: 0.35)) { foldSpan = newValue }
        }
    }

    private var mountedSlots: [Slot] {
        guard !items.isEmpty else { return [] }
        guard viewport.width > 0 else {
            return (0..<min(items.count, Self.initialCount)).map { Slot(index: $0, item: items[$0]) }
        }
        let overscan = max(400, viewport.height / 2)
        let minY = viewport.minY - overscan
        let maxY = viewport.maxY + overscan
        var indices = IndexSet()
        for var config in [grid] + morphTargets {
            config.foldSpan = foldSpan
            indices.insert(integersIn: config.itemRange(
                fromY: minY, toY: maxY, width: viewport.width, itemCount: items.count
            ))
        }
        return indices.map { Slot(index: $0, item: items[$0]) }
    }

    private static func snappedViewport(_ proxy: GeometryProxy) -> CGRect {
        guard let visible = proxy.bounds(of: .scrollView) else {
            // Not inside a scroll view: treat the whole grid as visible.
            return CGRect(origin: .zero, size: proxy.size)
        }
        let minY = (visible.minY / snap).rounded(.down) * snap
        let maxY = (visible.maxY / snap).rounded(.up) * snap
        return CGRect(x: 0, y: minY, width: proxy.size.width, height: maxY - minY)
    }
}
