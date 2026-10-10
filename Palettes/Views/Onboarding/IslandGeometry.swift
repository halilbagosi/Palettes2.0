//
//  IslandGeometry.swift
//  Palettes
//
//  Where the orb is pulled from: the Dynamic Island or the notch on iPhones
//  whose cutout sits centered at the top, and the top bezel everywhere else
//  (iPad, iPhone Duo, landscape). There is no public API for the cutout's
//  frame, so a centered cutout is recognised by the iPhone's screen size and
//  the inset (and, for the smaller iPhone 18 Pro island, the model) is
//  mapped to the hardware's known sizes. Any other device,
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
    /// pulls from the top edge: the bezel, or a window's top on iPad.
    static func make(topInset: CGFloat, screenSize: CGSize) -> IslandGeometry {
        if screenSize.height > screenSize.width,
           centeredCutoutSizes.contains(Size(screenSize.width, screenSize.height)) {
            // The cutout's bottom edge sits a fixed distance above the safe
            // area on each kind of hardware, so it's placed from the inset:
            // the neck must leave from exactly that edge to read as one black
            // shape with the real cutout.
            if topInset >= 59 {
                // 37 pt tall, its bottom 11 pt above the safe area (top 14 at a
                // 62 pt inset, 11 at 59). iPhone 18 Pro's is as tall and sits as
                // high, only narrower: 95 pt rather than 125.
                let height: CGFloat = 37
                return IslandGeometry(kind: .dynamicIsland, width: hasCompactIsland ? 95 : 125,
                                      height: height, top: topInset - 11 - height)
            }
            if topInset >= 44 {
                // The notch runs from the top edge to 14 pt above the safe area
                // (30 pt deep at a 44 pt inset, 33 at 47).
                let height = min(max(topInset - 14, 28), 36)
                return IslandGeometry(kind: .notch, width: 160, height: height, top: 0)
            }
        }
        return .bezel
    }

    /// iPhone 18 Pro and Pro Max keep the 17 Pro's screen sizes and insets but
    /// have a narrower Dynamic Island, so they're told apart by model: the
    /// iPhone 18 family's identifiers start at iPhone19,x, and later models
    /// are assumed to keep the smaller island.
    static let hasCompactIsland: Bool = {
        guard let identifier = modelIdentifier, identifier.hasPrefix("iPhone") else { return false }
        let major = identifier.dropFirst("iPhone".count).prefix { $0.isNumber }
        return (Int(major) ?? 0) >= 19
    }()

    /// The hardware model, e.g. "iPhone18,1"; the simulated one in Simulator.
    private static var modelIdentifier: String? {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
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

    /// The drawn shape's bottom edge as a flat run between two rounded ends,
    /// for joining the neck to it smoothly. Nil for the bezel and none.
    nonisolated struct BottomEdge {
        /// Half the flat run's width, from the centre line.
        var flatHalfWidth: CGFloat
        /// Radius of the rounded ends, and the y of their centres.
        var cornerRadius: CGFloat
        var cornerCenterY: CGFloat
    }

    var bottomEdge: BottomEdge? {
        switch kind {
        case .dynamicIsland:
            let radius = drawnHeight / 2
            return BottomEdge(flatHalfWidth: (width - 2 * Self.drawInset) / 2 - radius,
                              cornerRadius: radius, cornerCenterY: drawnBottom - radius)
        case .notch:
            let radius = Self.notchBottomRadius - Self.drawInset
            return BottomEdge(flatHalfWidth: (width - 2 * Self.drawInset) / 2 - radius,
                              cornerRadius: radius, cornerCenterY: drawnBottom - radius)
        case .bezel, .none:
            return nil
        }
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
