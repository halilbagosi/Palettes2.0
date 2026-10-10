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
    func onFoldChange(_ action: @escaping (Fold?) -> Void) -> some View {
        onGeometryChange(for: Fold?.self) { proxy in
            proxy.activeFold?.dividing(proxy.size)
        } action: { fold in
            action(fold)
        }
    }
}
