//
//  IslandGeometry.swift
//  Palettes
//
//  Where the orb is pulled from: the Dynamic Island or the notch on iPhones
//  whose cutout sits centered at the top, and the top bezel everywhere else
//  (iPad, iPhone Duo, landscape). There is no public API for the cutout's
//  frame, so a centered cutout is recognised by the iPhone's screen size and
//  the inset is mapped to the hardware's known sizes. Any other device,
//  including one with an off-center cutout, pulls from the bezel.
//

import SwiftUI

nonisolated struct IslandGeometry: Equatable {
    nonisolated enum Kind: Equatable {
        case dynamicIsland, notch
        /// No centered cutout: the orb is pulled out of the top edge of the screen.
        case bezel
        case none
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
    /// The bezel is drawn as a band this deep above the screen edge, and this
    /// far past either side, so the blur never thins it where it meets the drop.
    static let bezelDepth: CGFloat = 40
    /// The bezel's "island" sits just above the screen edge; the drop starts as
    /// a circle half this tall, tucked out of sight behind it.
    static let bezelHeight: CGFloat = 20

    static let none = IslandGeometry(kind: .none, width: 0, height: 0, top: 0)
    static let bezel = IslandGeometry(kind: .bezel, width: 0, height: bezelHeight, top: -bezelHeight)

    /// Portrait screen sizes (points) of the iPhones with a cutout centered at
    /// the top: X through 17 Pro Max, and Air.
    static let centeredCutoutSizes: Set<Size> = [
        Size(375, 812), Size(414, 896), Size(390, 844), Size(428, 926),
        Size(393, 852), Size(430, 932), Size(402, 874), Size(440, 956),
        Size(420, 912),
    ]

    /// Portrait iPhones with a centered cutout pull from it. Everything else
    /// pulls from the bezel, as long as the window reaches the top edge of the
    /// screen; a floating window (Stage Manager, Slide Over) has no morph.
    static func make(topInset: CGFloat, screenSize: CGSize, reachesTopEdge: Bool = true) -> IslandGeometry {
        if screenSize.height > screenSize.width,
           centeredCutoutSizes.contains(Size(screenSize.width, screenSize.height)) {
            if topInset >= 59 {
                return IslandGeometry(kind: .dynamicIsland, width: 125, height: 37, top: topInset >= 62 ? 14 : 11)
            }
            if topInset >= 44 {
                return IslandGeometry(kind: .notch, width: 160, height: 31, top: 0)
            }
        }
        return reachesTopEdge ? .bezel : .none
    }

    /// A screen size rounded to whole points, so it can be looked up.
    nonisolated struct Size: Hashable {
        let width: Int
        let height: Int
        init(_ width: CGFloat, _ height: CGFloat) {
            self.width = Int(width.rounded())
            self.height = Int(height.rounded())
        }
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
        case .bezel:
            let y = -Self.bezelDepth
            return CGRect(
                x: -Self.bezelDepth,
                y: y,
                width: screenWidth + 2 * Self.bezelDepth,
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
        case .bezel:
            return Rectangle().path(in: rect)
        case .none:
            return Path()
        }
    }
}
