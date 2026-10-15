//
//  SheetLayout.swift
//  Palettes
//
//  The shared stacked-versus-split decision for sheets that have a visual
//  (swatch, strip) and controls (ColorComposer, PaletteEditor).
//

import SwiftUI

/// How a sheet arranges its visual and its controls.
enum SheetLayout: Equatable {
    /// Visual above controls.
    case stacked
    /// Visual and controls side by side.
    case split

    /// The least width a split column can have and still be usable.
    static let minColumnWidth: CGFloat = 300
    /// The widest container (width ÷ height) that still stacks when it is
    /// tall enough. iPhone landscape (~2.2) and full-width iPad landscape
    /// sheets (~1.4) are wider and split.
    static let maxStackedAspect: CGFloat = 1.25

    /// Decides the layout for a container of `size`.
    ///
    /// A container that is roughly square or taller (width at most
    /// `maxStackedAspect` times its height) and tall enough to stack stays
    /// stacked. That covers iPhone Duo unfolded in both orientations, where
    /// the sheet is a near-square card, so turning the device doesn't
    /// rearrange it. Size alone decides: inside a sheet the size classes
    /// don't tell Duo landscape from portrait. A half-open fold is handled
    /// by `SheetLayoutReader` before this. Otherwise split when the container is landscape-shaped, when it is regular-width
    /// with room for two columns (width at least 0.75 of height; a ratio, not
    /// points), or when it is too short for the stacked layout
    /// (`size.height < minStackedHeight`, computed from content with
    /// `@ScaledMetric`) AND wide enough for two usable columns
    /// (`2 * minColumnWidth`). A narrow, short container stays stacked and
    /// scrolls rather than squeezing into two cramped columns.
    static func resolve(size: CGSize, horizontal: UserInterfaceSizeClass?, minStackedHeight: CGFloat) -> SheetLayout {
        if size.width <= size.height * maxStackedAspect, size.height >= minStackedHeight { return .stacked }
        if size.width > size.height { return .split }
        if horizontal == .regular, size.width >= size.height * 0.75 { return .split }
        if size.height < minStackedHeight, size.width >= minColumnWidth * 2 { return .split }
        return .stacked
    }
}

/// Turns raw (size, bottom safe-area inset) readings into the size the layout
/// decision should use, ignoring the shrink the software keyboard causes.
///
/// A sheet's frame shrinks when the keyboard appears, and the keyboard shows up
/// as a bottom inset at least `keyboardThreshold` above the no-keyboard
/// baseline. While it does, a height-only shrink is ignored. Heuristic limits:
/// a host that adds its own bottom safe-area inset (an inset bar) of 100pt or
/// more, or a hardware-keyboard shortcut bar, can look like a keyboard; the
/// baseline re-learns when the inset rises without the height shrinking, or
/// when the height grows. A rotation or first reading with the keyboard already
/// up cannot see the full height, so it is estimated by adding back
/// `inset - assumedHomeInset`; that estimate is only as good as the assumed
/// home-indicator inset.
nonisolated struct SheetMeasureTracker: Equatable, Sendable {
    static let keyboardThreshold: CGFloat = 100
    static let widthTolerance: CGFloat = 0.5
    static let assumedHomeInset: CGFloat = 34

    private(set) var size: CGSize = .zero
    private var baseInset: CGFloat = 0

    /// Feeds a reading and returns the size to lay out with.
    @discardableResult
    mutating func apply(size new: CGSize, bottomInset inset: CGFloat) -> CGSize {
        let widthChanged = size == .zero || abs(new.width - size.width) > Self.widthTolerance
        if widthChanged {
            if inset >= Self.keyboardThreshold {
                // Keyboard probably up: the frame is shrunk, so add it back.
                size = CGSize(width: new.width, height: new.height + inset - Self.assumedHomeInset)
                baseInset = Self.assumedHomeInset
            } else {
                size = new
                baseInset = inset
            }
            return size
        }
        let keyboardUp = inset >= baseInset + Self.keyboardThreshold
        let shrank = new.height < size.height
        if keyboardUp, shrank { return size }
        // An inset rise with no shrink is not the keyboard; growth means the
        // inset is the new normal. Either way, re-baseline.
        baseInset = shrank ? min(baseInset, inset) : inset
        size = new
        return size
    }
}

private nonisolated struct SheetMeasure: Equatable, Sendable {
    var size: CGSize
    var bottomInset: CGFloat
}

/// Fills its container, measures it, and hands `content` the resolved `SheetLayout`
/// and the active `Fold?` (nil unless a fold divides the container).
///
///     SheetLayoutReader(minStackedHeight: min) { layout, fold in … }
///
/// Size is measured with `onGeometryChange` (it changes on window resize or
/// device fold/unfold); the fold comes from `onFoldChange`'s `GeometryReader`,
/// because folding doesn't change the size. Until the first measurement the
/// layout is `.stacked`. The reader always fills its proposed space
/// (`maxWidth/maxHeight: .infinity`) so it measures the container, not the
/// content; the fold is in that container's coordinates.
///
/// The keyboard does not change the layout: see `SheetMeasureTracker` for how
/// its frame shrink is ignored (and the heuristic's limits).
struct SheetLayoutReader<Content: View>: View {
    var minStackedHeight: CGFloat
    @ViewBuilder var content: (SheetLayout, Fold?) -> Content

    @Environment(\.horizontalSizeClass) private var horizontal
    @State private var tracker = SheetMeasureTracker()
    @State private var fold: Fold?

    private var layout: SheetLayout {
        tracker.size == .zero ? .stacked
            : .resolve(size: tracker.size, horizontal: horizontal, minStackedHeight: minStackedHeight)
    }

    var body: some View {
        content(layout, fold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: SheetMeasure.self) { SheetMeasure(size: $0.size, bottomInset: $0.safeAreaInsets.bottom) } action: { new in
                tracker.apply(size: new.size, bottomInset: new.bottomInset)
            }
            .onFoldChange { fold = $0 }
    }
}

#Preview("Reader") {
    SheetLayoutReader(minStackedHeight: 300) { layout, _ in
        Text(layout == .split ? "split" : "stacked")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
