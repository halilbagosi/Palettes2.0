//
//  IslandGeometry.swift
//  Palettes
//
//  Where the orb is pulled from: the Dynamic Island or the notch on iPhones
//  whose cutout sits centered at the top, and the top bezel everywhere else
//  (iPad, iPhone Duo, landscape). There is no public API for the cutout's
//  frame, so a centered cutout is recognised by the iPhone's screen size and
//  placed from the top safe-area inset: each cutout's bottom edge sits a fixed
//  distance above it, which also follows the iPhone Air's lower island. Every
//  cutout is drawn at the size of the smallest one (the iPhone 18 Pro's
//  island), so the drawn shape hides behind the real one on every device and
//  the neck meets it the same way everywhere. Any other device, including one
//  with an off-center cutout, pulls from the bezel.
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
    /// Hardware size of the smallest cutout, the iPhone 18 Pro's island. Every
    /// island and notch is drawn this wide, and islands this tall.
    static let cutoutWidth: CGFloat = 84
    static let cutoutHeight: CGFloat = 34
    /// How far above the top safe-area inset the cutout's bottom edge sits.
    static let islandGap: CGFloat = 11
    static let notchGap: CGFloat = 14
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
    /// pulls from the top edge: the bezel, or a window's top on iPad.
    static func make(topInset: CGFloat, screenSize: CGSize) -> IslandGeometry {
        if screenSize.height > screenSize.width,
           centeredCutoutSizes.contains(Size(screenSize.width, screenSize.height)) {
            // The neck must leave from exactly the cutout's bottom edge to read
            // as one black shape with it, so the edge is placed from the inset
            // (an island's bottom is 11 pt above it: 48 at a 59 pt inset, 51 at
            // 62, 57 on the Air's 68).
            if topInset >= 59 {
                return IslandGeometry(kind: .dynamicIsland, width: cutoutWidth, height: cutoutHeight,
                                      top: topInset - islandGap - cutoutHeight)
            }
            if topInset >= 44 {
                // The notch runs from the top edge to 14 pt above the safe area
                // (30 pt deep at a 44 pt inset, 33 at 47, 36 at 50).
                return IslandGeometry(kind: .notch, width: cutoutWidth, height: topInset - notchGap, top: 0)
            }
        }
        return .bezel
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

    /// Radius of the drawn shape's bottom corners: the island's round ends, and
    /// the same on the notch, so the neck meets both alike.
    static let drawnCornerRadius: CGFloat = cutoutHeight / 2 - drawInset

    /// Half the length of the drawn shape's flat bottom edge, where the neck's
    /// fillets can meet it tangentially.
    var drawnFlatHalfWidth: CGFloat {
        guard kind == .dynamicIsland || kind == .notch else { return 0 }
        return max(0, width / 2 - Self.drawInset - Self.drawnCornerRadius)
    }

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
            let r = Self.drawnCornerRadius
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
