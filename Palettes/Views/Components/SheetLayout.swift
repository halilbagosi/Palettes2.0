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
struct SheetLayoutReader<Content: View>: View {
    var minStackedHeight: CGFloat
    @ViewBuilder var content: (SheetLayout, Fold?) -> Content

    @Environment(\.horizontalSizeClass) private var horizontal
    @State private var size: CGSize = .zero
    @State private var fold: Fold?

    private var layout: SheetLayout {
        size == .zero ? .stacked
            : .resolve(size: size, horizontal: horizontal, minStackedHeight: minStackedHeight)
    }

    var body: some View {
        content(layout, fold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .onFoldChange { fold = $0 }
    }
}

#Preview("Reader") {
    SheetLayoutReader(minStackedHeight: 300) { layout, _ in
        Text(layout == .split ? "split" : "stacked")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
