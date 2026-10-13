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

    /// Decides the layout for a container of `size`.
    ///
    /// Split when the container is landscape-shaped, when it is regular-width
    /// with room for two columns (width at least 0.75 of height; a ratio, not
    /// points), or when it is too short for the stacked layout
    /// (`size.height < minStackedHeight`, computed from content with
    /// `@ScaledMetric`, never a screen constant). Otherwise stacked.
    static func resolve(size: CGSize, horizontal: UserInterfaceSizeClass?, minStackedHeight: CGFloat) -> SheetLayout {
        if size.width > size.height { return .split }
        if horizontal == .regular, size.width >= size.height * 0.75 { return .split }
        if size.height < minStackedHeight { return .split }
        return .stacked
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
/// The keyboard does not change the layout. A sheet's frame shrinks when the
/// keyboard appears (the content must stay above it; `ignoresSafeArea(.keyboard)`
/// on a measuring background does not undo that in a sheet, and no keyboard
/// notification arrives reliably), so measuring it naively would drop a
/// portrait sheet below `minStackedHeight`, flip it to split, tear down the
/// focused field and dismiss the keyboard, oscillating. The keyboard shows up
/// as a bottom safe-area inset larger than the smallest seen at this width, and
/// while it does a height-only shrink is ignored; a width change (rotation,
/// window resize) is real and applies.
struct SheetLayoutReader<Content: View>: View {
    var minStackedHeight: CGFloat
    @ViewBuilder var content: (SheetLayout, Fold?) -> Content

    @Environment(\.horizontalSizeClass) private var horizontal
    @State private var size: CGSize = .zero
    @State private var fold: Fold?
    /// Smallest bottom safe-area inset seen at the current width: the inset
    /// with no keyboard (home indicator).
    @State private var baseInset: CGFloat = .infinity

    private var layout: SheetLayout {
        size == .zero ? .stacked
            : .resolve(size: size, horizontal: horizontal, minStackedHeight: minStackedHeight)
    }

    private func apply(_ new: SheetMeasure) {
        if new.size.width != size.width { baseInset = .infinity }
        baseInset = min(baseInset, new.bottomInset)
        // A bigger bottom inset than the keyboard-less one means the keyboard
        // is up and has shrunk the frame: keep the full-height size.
        let keyboardUp = new.bottomInset > baseInset + 1
        if keyboardUp, size != .zero, new.size.width == size.width, new.size.height < size.height { return }
        size = new.size
    }

    var body: some View {
        content(layout, fold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: SheetMeasure.self) { SheetMeasure(size: $0.size, bottomInset: $0.safeAreaInsets.bottom) } action: { new in
                apply(new)
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
