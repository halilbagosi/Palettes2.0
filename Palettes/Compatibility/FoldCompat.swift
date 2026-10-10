//
//  FoldCompat.swift
//  Palettes
//
//  The fold of iPhone Duo's inner display while the device is half open, read
//  from the iOS 27.1 reserved-regions API (`GeometryProxy.reservedRegions`,
//  kind `.division`). Custom layouts use it to put content on either side of
//  the crease instead of across it. The HIG: "Adapt your layout when the
//  device folds … Use the ReservedRegion API to keep important elements clear
//  of the center."
//
//  The fold is nil on every other device, when iPhone Duo is closed or fully
//  open, on systems before iOS 27.1, and when built with an SDK older than
//  Xcode 27's (Swift 6.4). Note that Xcode 27.0's SDK predates the API: build
//  with Xcode 27.1 or later, or with Xcode 26 (which skips this code).
//

import SwiftUI

nonisolated struct Fold: Equatable {
    /// The crease, in the measured view's coordinate space, including the
    /// margins content should keep clear of.
    var frame: CGRect

    /// The crease runs top to bottom, splitting the view into leading and
    /// trailing sides (the device is held in landscape, half open).
    var isVertical: Bool { frame.height >= frame.width }

    /// The crease's extent across the split axis: x for a vertical crease,
    /// y for a horizontal one.
    var span: ClosedRange<CGFloat> {
        isVertical ? frame.minX...frame.maxX : frame.minY...frame.maxY
    }

    func offsetBy(dx: CGFloat, dy: CGFloat) -> Fold {
        Fold(frame: frame.offsetBy(dx: dx, dy: dy))
    }

    /// The fold only if it actually divides `size` into two usable sides.
    func dividing(_ size: CGSize, minimumSide: CGFloat = 120) -> Fold? {
        let length = isVertical ? size.width : size.height
        return span.lowerBound >= minimumSide && length - span.upperBound >= minimumSide ? self : nil
    }
}

extension GeometryProxy {
    /// The active fold crossing this view, if any.
    var activeFold: Fold? {
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) {
            return reservedRegions(kind: .division)
                .first(where: \.isActive)
                .map { Fold(frame: $0.frame) }
        }
        #endif
        return nil
    }

    /// The x extent of an active vertical fold, for layouts that scroll
    /// vertically: unlike the full frame it doesn't change as they scroll.
    var verticalFoldSpan: ClosedRange<CGFloat>? {
        guard let fold = activeFold, fold.isVertical else { return nil }
        return fold.span
    }
}

extension View {
    /// Reports the active fold crossing this view, in its own coordinates.
    ///
    /// Read from a `GeometryReader`, as Apple's examples do: folding the
    /// device changes the reserved regions without changing the view's size,
    /// and `onGeometryChange` only re-measures when the size or position
    /// changes, so it would miss a fold made while the view is on screen.
    func onFoldChange(_ action: @escaping (Fold?) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                let fold = proxy.activeFold?.dividing(proxy.size)
                Color.clear
                    .onAppear { action(fold) }
                    .onChange(of: fold) { _, newFold in action(newFold) }
            }
        }
    }

    /// Reports the x extent of an active vertical fold across this view, for
    /// layouts that scroll vertically (see `GeometryProxy.verticalFoldSpan`).
    func onVerticalFoldSpanChange(_ action: @escaping (ClosedRange<CGFloat>?) -> Void) -> some View {
        background {
            GeometryReader { proxy in
                let span = proxy.verticalFoldSpan
                Color.clear
                    .onAppear { action(span) }
                    .onChange(of: span) { _, newSpan in action(newSpan) }
            }
        }
    }

    /// Fades the view out over `length` at the given edges, so scrolling
    /// content softens away instead of being cut off.
    ///
    /// The other edges stay open: a scroll view draws into the safe area
    /// around it, and a glow (the Generate orb's) spreads past its frame, so
    /// a mask the size of the frame would cut them off in a hard line.
    func fadingEdges(_ edges: VerticalEdge.Set, length: CGFloat) -> some View {
        let overflow: CGFloat = 2000
        return mask {
            VStack(spacing: 0) {
                if edges.contains(.top) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: length)
                }
                Rectangle()
                if edges.contains(.bottom) {
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: length)
                }
            }
            .padding(.horizontal, -overflow)
            .padding(.top, edges.contains(.top) ? 0 : -overflow)
            .padding(.bottom, edges.contains(.bottom) ? 0 : -overflow)
        }
    }
}

/// Splits its space at `fold`: `visual` on the side before the crease (the
/// top, or the leading side in landscape) and `controls` after it, so text,
/// buttons and controls always end up on the trailing or bottom side.
/// Measure `fold` on the view this fills, so the coordinates match.
struct FoldSplit<Visual: View, Controls: View>: View {
    let fold: Fold
    @ViewBuilder var visual: Visual
    @ViewBuilder var controls: Controls

    var body: some View {
        let span = fold.span
        let vertical = fold.isVertical
        let layout = vertical ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
        layout {
            visual
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(width: vertical ? span.lowerBound : nil,
                       height: vertical ? nil : span.lowerBound)
                // Above the controls: a glass orb stretched over them bends them.
                .zIndex(1)
            Color.clear
                .frame(width: vertical ? span.upperBound - span.lowerBound : nil,
                       height: vertical ? nil : span.upperBound - span.lowerBound)
            controls
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A `LazyVGrid` whose columns split evenly either side of iPhone Duo's fold
/// while it's half open in landscape, like `MorphingCardGrid`; otherwise an
/// adaptive grid of `minimum`…`maximum` wide columns.
struct FoldAwareGrid<Content: View>: View {
    var minimum: CGFloat
    var maximum: CGFloat
    var spacing: CGFloat
    var rowSpacing: CGFloat
    @ViewBuilder var content: Content

    @State private var width: CGFloat = 0
    @State private var foldSpan: ClosedRange<CGFloat>?

    var body: some View {
        grid
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .onVerticalFoldSpanChange { newValue in
                withAnimation(.smooth(duration: 0.35)) { foldSpan = newValue }
            }
    }

    @ViewBuilder
    private var grid: some View {
        if let split = split {
            LazyVGrid(columns: split.columns, spacing: rowSpacing) { content }
                // Equal sides, so the gap after the middle column lands on the crease.
                .padding(.leading, split.leadingPad)
                .padding(.trailing, split.trailingPad)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: spacing)],
                      spacing: rowSpacing) { content }
        }
    }

    private struct Split {
        var columns: [GridItem]
        var leadingPad: CGFloat
        var trailingPad: CGFloat
    }

    private var split: Split? {
        guard let fold = foldSpan, width > 0 else { return nil }
        let leading = fold.lowerBound
        let trailing = width - fold.upperBound
        guard leading > 0, trailing > 0 else { return nil }
        let side = min(leading, trailing)
        let perSide = max(1, Int((side + spacing) / (minimum + spacing)))
        var columns = Array(repeating: GridItem(.flexible(maximum: maximum), spacing: spacing),
                            count: perSide * 2)
        columns[perSide - 1].spacing = fold.upperBound - fold.lowerBound
        return Split(columns: columns, leadingPad: leading - side, trailingPad: trailing - side)
    }
}

extension View {
    /// Centres the view on the screen rather than on the safe area, for when
    /// bars sit along one side (iPhone Duo in landscape): the side with less
    /// inset is padded to match the other.
    func centeredOnScreen(_ enabled: Bool = true) -> some View {
        modifier(ScreenCentering(enabled: enabled))
    }
}

private struct ScreenCentering: ViewModifier {
    let enabled: Bool

    /// Measured in the same pass as the layout, not stored after it: a
    /// stored inset starts at zero, so the view would first appear off
    /// centre and then slide over once the measurement landed.
    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            GeometryReader { proxy in
                let side = max(proxy.safeAreaInsets.leading, proxy.safeAreaInsets.trailing)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, side)
            }
            // Only the side insets: the keyboard and bars still push it as before.
            .ignoresSafeArea(.container, edges: .horizontal)
        } else {
            content
        }
    }
}
