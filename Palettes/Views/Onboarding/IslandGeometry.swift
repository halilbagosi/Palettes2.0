//
//  IslandGeometry.swift
//  Palettes
//
//  Where the Dynamic Island (or the notch) sits, derived from the window's top
//  safe-area inset. There is no public API for the cutout's frame, so this
//  maps the inset to the hardware's known sizes. Portrait only.
//

import SwiftUI

nonisolated struct IslandGeometry: Equatable {
    nonisolated enum Kind: Equatable {
        case dynamicIsland, notch, none
    }

    let kind: Kind
    /// Hardware size and distance from the top of the screen.
    let width: CGFloat
    let height: CGFloat
    let top: CGFloat

    /// The drawn shape is this much smaller than the hardware on every side,
    /// so any mismatch hides behind the real cutout.
    static let drawInset: CGFloat = 1
    /// The notch is drawn this far above the screen edge so it fuses with the bezel.
    static let notchOverhang: CGFloat = 10
    static let notchBottomRadius: CGFloat = 20

    static let none = IslandGeometry(kind: .none, width: 0, height: 0, top: 0)

    /// Portrait phones only; landscape and everything else has no morph.
    static func make(topInset: CGFloat, screenSize: CGSize) -> IslandGeometry {
        guard screenSize.height > screenSize.width else { return .none }
        if topInset >= 59 {
            return IslandGeometry(kind: .dynamicIsland, width: 125, height: 37, top: topInset >= 62 ? 14 : 11)
        }
        if topInset >= 44 {
            return IslandGeometry(kind: .notch, width: 160, height: 31, top: 0)
        }
        return .none
    }

    var hasMorph: Bool { kind != .none }

    /// Hardware bottom edge.
    var bottom: CGFloat { top + height }

    /// Bottom edge of the drawn shape.
    var drawnBottom: CGFloat { bottom - Self.drawInset }

    /// Height of the visible part of the drawn shape (the notch's overhang excluded).
    var drawnHeight: CGFloat { height - 2 * Self.drawInset }

    /// The drawn shape's rect in screen coordinates.
    func drawnRect(screenWidth: CGFloat) -> CGRect {
        switch kind {
        case .dynamicIsland:
            return CGRect(
                x: (screenWidth - width) / 2 + Self.drawInset,
                y: top + Self.drawInset,
                width: width - 2 * Self.drawInset,
                height: height - 2 * Self.drawInset
            )
        case .notch:
            let y = -Self.notchOverhang
            return CGRect(
                x: (screenWidth - width) / 2 + Self.drawInset,
                y: y,
                width: width - 2 * Self.drawInset,
                height: drawnBottom - y
            )
        case .none:
            return .zero
        }
    }

    func path(screenWidth: CGFloat) -> Path {
        let rect = drawnRect(screenWidth: screenWidth)
        switch kind {
        case .dynamicIsland:
            return Capsule(style: .continuous).path(in: rect)
        case .notch:
            let r = Self.notchBottomRadius - Self.drawInset
            return UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 0, bottomLeading: r, bottomTrailing: r, topTrailing: 0),
                style: .continuous
            ).path(in: rect)
        case .none:
            return Path()
        }
    }
}
