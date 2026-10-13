//
//  IslandMorph.swift
//  Palettes
//
//  The Dynamic Island (or notch) to orb morph. The island, a stretching neck
//  and a blob are drawn as a metaball in a `Canvas` (blur + alpha threshold),
//  and the goo is masked so only the part near the island is black. The drop
//  stays island-black (both schemes) until it separates from the island, then
//  dissolves into the real, clear glass orb drawn at the blob's frame.
//
//  On devices without a centered cutout (iPad, iPhone Duo) the island is the
//  top bezel: the edge dips under the finger as a flared U, which pinches off
//  into the drop and springs back flat.
//
//  Motion runs through `SpringValue`s rather than `withAnimation`, so a new
//  touch can grab the blob mid-flight and a release hands its velocity on.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Controller

@MainActor
final class IslandMorphController: ObservableObject {
    enum Phase: Equatable {
        /// Waiting for (or retracting from) a pull.
        case idle
        case dragging
        /// Past the threshold: the orb is springing to its resting place.
        case detaching
        case landed
    }

    enum Mode {
        /// Goo from the island.
        case morph
        /// No island, Reduce Motion, VoiceOver activation: the orb fades in at rest.
        case fade
    }

    struct Frame: Equatable {
        var center: CGPoint
        var diameter: CGFloat
    }

    /// Everything the controller needs to place things; set from the view's size.
    struct Placement: Equatable {
        var island: IslandGeometry
        var screenWidth: CGFloat
        var restCenter: CGPoint
        var restDiameter: CGFloat
    }

    // Tunables (points).
    static let pullRadiusEnd: CGFloat = 34
    static let pullRadiusRamp: CGFloat = 140
    /// The drop's radius as it starts out of an island or notch.
    static let cutoutStartRadius: CGFloat = 14
    static let pullTravelRatio: CGFloat = 0.85
    /// Width of the neck rod when the blob touches the island, and the width below
    /// which the blurred rod falls under the alpha threshold: the neck has snapped.
    static let neckWidth: CGFloat = 34
    static let neckBreakWidth: CGFloat = 12
    static let neckReach: CGFloat = 52
    /// An island's or notch's neck is short: it snaps soon after the drop
    /// clears the cutout, rather than stretching into a long thread.
    static let cutoutNeckReach: CGFloat = 22
    /// Dark stage: how far past the snap the held drop has to be pulled to
    /// have turned all the way into glass.
    static let darkRevealSpan: CGFloat = 24
    /// The bezel's neck is this fraction of the drop's width (capped at its pull
    /// size), so the edge dips as a U rather than a thin stem.
    static let bezelNeckRatio: CGFloat = 0.9
    /// The bezel's flared shoulders: half-width as a multiple of the drop's
    /// radius, and depth as a fraction of how far the drop pokes into the screen.
    static let bezelShoulderSpread: CGFloat = 2.4
    static let bezelShoulderDepth: CGFloat = 0.7
    /// The bezel drop keeps this far from the window's sides, clear of the
    /// display's rounded corners.
    static let bezelSideMargin: CGFloat = 90
    static let blur: CGFloat = 9
    /// An island's or notch's goo is blurred less: its neck snaps while the
    /// drop is still close, and a wider blur would bridge the gap on its own,
    /// so the neck would look full until it vanished in a frame. With this
    /// one the neck's own thinning shows and the pinch plays out gradually.
    static let cutoutBlur: CGFloat = 6
    /// Release velocity handed to the detach spring, in travels per second. Capped so a
    /// hard flick gives a lively overshoot rather than a fly-past.
    static let maxHandoffVelocity: Double = 2.4
    /// The orb's size may overshoot its rest size by at most this fraction of the way.
    static let maxSizeProgress: Double = 1.03

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var mode: Mode = .morph
    let pull = SpringValue(0)
    let detach = SpringValue(0)

    var placement: Placement
    /// Fires when the release commits (the coordinator advances the step).
    var onCommit: (() -> Void)?
    /// Fires when the orb has landed.
    var onLand: (() -> Void)?

    private var virtualStart: Double = 0
    /// Bezel only: where along the top edge the drop is pulled from (it follows
    /// the finger), and the finger's horizontal travel it was measured from.
    private var anchorX: CGFloat?
    private var anchorBase: CGFloat = 0
    private var release = Frame(center: .zero, diameter: 0)
    private var isSnapped = false
    /// Detach progress at the moment the drop snapped free of the island; nil before.
    private(set) var separatedAt: Double?
    /// How far the drop had turned to glass when it was let go.
    private var revealAtRelease: Double = 0
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)

    init(placement: Placement) {
        self.placement = placement
        pull.onUpdate = { [weak self] in self?.evaluateNeck() }
        detach.onUpdate = { [weak self] in self?.evaluateNeck() }
        detach.onSettle = { [weak self] in self?.landed() }
    }

    // MARK: Frames

    /// The blob while pulling. `d` is the pull in points.
    func pullFrame(_ d: Double) -> Frame {
        let island = placement.island
        let progress = Easing.clamp01(d / Self.pullRadiusRamp)
        let r: CGFloat
        if island.kind == .bezel {
            r = Easing.lerp(island.drawnHeight / 2, Self.pullRadiusEnd, progress)
        } else {
            // Narrow while it leaves the cutout and swelling as it moves away,
            // so the neck's fillets have room on the smallest island's flat
            // bottom while the drop is still against it.
            r = Easing.lerp(min(island.drawnHeight / 2, Self.cutoutStartRadius), Self.pullRadiusEnd,
                            pow(progress, 1.5))
        }
        return Frame(
            center: CGPoint(x: pullX,
                            y: island.drawnBottom - r + d * Self.pullTravelRatio),
            diameter: r * 2
        )
    }

    /// The island's center, or on the bezel, under the finger.
    private var pullX: CGFloat {
        if placement.island.kind == .bezel, let anchorX { return clampedPullX(anchorX) }
        return placement.screenWidth / 2
    }

    private func clampedPullX(_ x: CGFloat) -> CGFloat {
        let width = placement.screenWidth
        let margin = min(Self.bezelSideMargin, width / 2)
        return min(max(x, margin), width - margin)
    }

    /// Where the orb is right now, for the current phase.
    var orbFrame: Frame {
        let rest = Frame(center: placement.restCenter, diameter: placement.restDiameter)
        if mode == .fade || placement.island.kind == .none { return rest }
        switch phase {
        case .idle, .dragging:
            return pullFrame(pull.value)
        case .detaching, .landed:
            let t = detach.value
            return Frame(
                center: CGPoint(x: Easing.lerp(release.center.x, rest.center.x, t),
                                y: Easing.lerp(release.center.y, rest.center.y, t)),
                diameter: max(0, Easing.lerp(release.diameter, rest.diameter, min(t, Self.maxSizeProgress)))
            )
        }
    }

    /// Distance between the island's bottom edge and the blob's top.
    var neckGap: CGFloat {
        let frame = orbFrame
        return (frame.center.y - frame.diameter / 2) - placement.island.drawnBottom
    }

    /// Width of the neck where it meets the island. The bezel's is nearly as
    /// wide as the drop; it is capped at the drop's pull size so the neck does
    /// not re-form as the orb grows on its way to rest.
    var neckBase: CGFloat {
        guard placement.island.kind == .bezel else { return Self.neckWidth }
        let diameter = min(orbFrame.diameter, Self.pullRadiusEnd * 2)
        return max(Self.neckWidth, diameter * Self.bezelNeckRatio)
    }

    /// Width of the rod bridging island and blob right now.
    var neckRodWidth: CGFloat { Self.neckRodWidth(gap: neckGap, base: neckBase, reach: currentNeckReach) }

    /// How far the neck stretches before it has thinned away.
    var currentNeckReach: CGFloat {
        placement.island.kind == .bezel ? Self.neckReach : Self.cutoutNeckReach
    }

    /// Width of the rod bridging island and blob: full while they touch,
    /// thinning as they part.
    static func neckRodWidth(gap: CGFloat, base: CGFloat = neckWidth, reach: CGFloat = neckReach) -> CGFloat {
        guard gap > 0 else { return base }
        let snap = snapGap(base: base, reach: reach)
        if gap <= snap { return base * (1 - gap / reach) }
        // Past the snap, the drip and the peak it leaves recoil over the same
        // stretch however short the neck was, so they read as liquid letting go.
        return max(0, neckBreakWidth * (1 - (gap - snap) / (neckReach * neckBreakWidth / base)))
    }

    /// The gap at which the blurred rod drops under the threshold and snaps.
    static func snapGap(base: CGFloat = neckWidth, reach: CGFloat = neckReach) -> CGFloat {
        reach * (1 - neckBreakWidth / base)
    }

    /// Opacity of the orb: it forms out of the island over the first few points of the pull.
    var orbOpacity: Double {
        if mode == .fade || placement.island.kind == .none {
            return Easing.smoothstep(0, 0.6, detach.value)
        }
        switch phase {
        case .idle, .dragging: return Easing.smoothstep(0, 14, pull.value)
        case .detaching, .landed: return 1
        }
    }

    /// How joined the drop still is to the island: 1 with a full neck, 0 once
    /// it has snapped.
    var neckConnected: Double {
        let base = neckBase
        let rod = Self.neckRodWidth(gap: neckGap, base: base, reach: currentNeckReach)
        return Easing.clamp01(Double((rod - Self.neckBreakWidth) / (base - Self.neckBreakWidth)))
    }

    /// How settled the orb is on the stage, 0...1. Its shadow and the stage
    /// light follow this, so they gather in over the travel rather than
    /// switching on when it lands. Zero while the drop is joined to the island.
    var settle: Double {
        switch phase {
        case .idle, .dragging:
            return 0
        case .landed:
            return 1
        case .detaching:
            let t = Easing.clamp01(detach.value)
            if mode == .fade || placement.island.kind == .none {
                return Easing.smoothstep(0.1, 0.95, t)
            }
            guard let start = separatedAt else { return 0 }
            return Easing.smoothstep(start, 0.98, t)
        }
    }

    /// How far the island-black drop has turned into clear
    /// glass. It stays black while joined (the glass rim would read as a
    /// circle against the black neck) and from the moment it separates eases
    /// into glass: while still held, over the next stretch of the pull, and
    /// after release from wherever that left it over most of the remaining
    /// travel, so the change is one long, even dissolve rather than a swap.
    var glassReveal: Double {
        guard mode == .morph, placement.island.kind != .none else { return 1 }
        switch phase {
        case .idle, .dragging:
            return pullGlassReveal
        case .detaching:
            guard neckConnected <= 0.001, let start = separatedAt else { return 0 }
            let t = Easing.smoothstep(start, max(start + 0.2, min(start + 0.7, 0.98)), Easing.clamp01(detach.value))
            return Easing.lerp(revealAtRelease, 1, t)
        case .landed:
            return 1
        }
    }

    /// Before release: clear from the snap over `darkRevealSpan` of pull, and
    /// back to black if the drop is pushed back into the island.
    private var pullGlassReveal: Double {
        let snap = Self.snapGap(base: neckBase, reach: currentNeckReach)
        return Easing.smoothstep(Double(snap), Double(snap + Self.darkRevealSpan), Double(neckGap))
    }

    /// Whether the island goo is on screen. It exists only while pulling and detaching.
    var showsGoo: Bool {
        mode == .morph && placement.island.hasMorph && phase != .landed
    }

    // MARK: Gesture

    /// `time` is the touch event's timestamp (seconds), not the time it was handled:
    /// updates delivered in a batch must not look instantaneous. `location` is
    /// the finger in screen space; on the bezel the drop follows it sideways.
    func dragChanged(translation: CGSize, location: CGPoint, time: TimeInterval) {
        guard mode == .morph, placement.island.hasMorph else { return }
        if phase == .detaching || phase == .landed { return }
        if phase != .dragging {
            // Grab: pick up wherever the blob is (it may still be retracting).
            pull.freeze()
            virtualStart = OnboardingPull.inverseRubberBand(pull.value)
            // A fresh pull starts under the finger; a grab mid-retract keeps the
            // drop where it is and moves it from there.
            if let anchorX, pull.value >= 1 {
                anchorBase = clampedPullX(anchorX) - translation.width
            } else {
                anchorBase = location.x - translation.width
            }
            phase = .dragging
            rigid.prepare()
            soft.prepare()
        }
        anchorX = anchorBase + translation.width
        pull.track(OnboardingPull.rubberBand(virtualStart + translation.height), at: time)
    }

    func dragEnded(time: TimeInterval) {
        guard phase == .dragging else { return }
        let velocity = min(max(pull.releaseVelocity(at: time), -6000), 6000)
        let projected = OnboardingPull.projectedEnd(stretch: pull.value, velocity: velocity)
        if OnboardingPull.shouldCommit(projectedEnd: projected) {
            commit(velocity: velocity)
        } else {
            phase = .idle
            pull.animate(to: 0, response: 0.35, dampingFraction: 1, initialVelocity: velocity)
        }
    }

    private func commit(velocity: Double) {
        let from = pullFrame(pull.value)
        revealAtRelease = pullGlassReveal
        release = from
        let travel = placement.restCenter.y - from.center.y
        let normalised = travel > 1 ? min(max(velocity * Self.pullTravelRatio / travel, 0), Self.maxHandoffVelocity) : 0
        phase = .detaching
        separatedAt = isSnapped ? 0 : nil
        onCommit?()
        detach.jump(to: 0)
        // A soft settle: enough give to feel like water, no visible bounce.
        detach.animate(to: 1, response: 0.68, dampingFraction: 0.9, initialVelocity: normalised)
    }

    /// Fades the orb in at its resting place: no island, Reduce Motion, VoiceOver.
    func beginFade() {
        guard phase == .idle || phase == .dragging else { return }
        mode = .fade
        phase = .detaching
        onCommit?()
        detach.jump(to: 0)
        detach.animate(to: 1, response: 0.6, dampingFraction: 1)
    }

    /// Debug jump: already landed.
    func landImmediately() {
        mode = .fade
        detach.jump(to: 1)
        phase = .landed
    }

    /// DEBUG: holds the blob at a fixed stretch.
    func debugHold(pull d: Double) {
        phase = .dragging
        pull.jump(to: d)
    }

    func useFadeMode() { if phase == .idle { mode = .fade } }

    /// Back to the pull, if it has not started: Reduce Motion was turned off
    /// before the orb appeared.
    func useMorphMode() { if phase == .idle { mode = .morph } }

    // MARK: Events

    /// Fires the rigid haptic on the frame the neck actually snaps (and rearms
    /// when it re-forms on a retract).
    private func evaluateNeck() {
        guard mode == .morph else { return }
        let gap = neckGap
        let snapGap = Self.snapGap(base: neckBase, reach: currentNeckReach)
        if !isSnapped, gap >= snapGap {
            isSnapped = true
            if phase == .detaching, separatedAt == nil { separatedAt = detach.value }
            if phase != .landed { rigid.impactOccurred(intensity: 0.7) }
        } else if isSnapped, gap < snapGap - 6 {
            isSnapped = false
        }
    }

    private func landed() {
        guard phase == .detaching else { return }
        phase = .landed
        soft.impactOccurred()
        onLand?()
    }
}

// MARK: - Stage

/// Draws the goo and the orb at the controller's current frame. Observes the
/// springs directly so only this layer re-renders per frame.
struct IslandMorphStage<Orb: View>: View {
    @ObservedObject var controller: IslandMorphController
    @ObservedObject var pull: SpringValue
    @ObservedObject var detach: SpringValue
    /// Receives the orb's current diameter and how settled it is (0...1).
    @ViewBuilder var orb: (CGFloat, Double) -> Orb

    init(controller: IslandMorphController, @ViewBuilder orb: @escaping (CGFloat, Double) -> Orb) {
        self.controller = controller
        self.pull = controller.pull
        self.detach = controller.detach
        self.orb = orb
    }

    var body: some View {
        let frame = controller.orbFrame
        let fade = controller.mode == .fade || controller.placement.island.kind == .none
        let t = detach.value
        let fadeScale = fade && !reduceMotion ? Easing.lerp(0.9, 1, Easing.clamp01(t)) : 1
        let fadeBlur = fade && !reduceMotion ? (1 - Easing.smoothstep(0, 0.7, t)) * 8 : 0
        // Both schemes: the black drop dissolves into glass after it separates.
        let dark = !fade
        let glassReveal = dark ? controller.glassReveal : 1
        // The glass comes into focus as it appears, so the handoff reads as
        // the drop clearing rather than one circle swapped for another.
        let revealBlur = dark && !reduceMotion ? (1 - glassReveal) * 5 : 0
        // The black fades a beat behind the glass: the two never both sit at
        // half strength, which would read as a grey disc mid-fade.
        let gooOpacity = dark ? 1 - Easing.smoothstep(0.15, 1, glassReveal) : 1
        ZStack {
            orb(frame.diameter, controller.settle)
                .scaleEffect(fadeScale)
                .blur(radius: fadeBlur + revealBlur)
                .opacity(controller.orbOpacity * (dark ? Easing.smoothstep(0, 0.85, glassReveal) : 1))
                .position(frame.center)
            // The goo sits above the glass: the island's black covers the part of
            // the orb still tucked behind it (so clear glass is never drawn over the
            // cutout, where it would read dark), and the neck's fade overlaps the
            // orb's top as black melting into glass.
            if controller.showsGoo {
                IslandGooCanvas(controller: controller, frame: frame)
                    // Dark: the black drop and neck fade out just behind the glass
                    // coming in, one dissolve with no seam between them.
                    .opacity(gooOpacity)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(controller.phase == .landed || fade)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

// MARK: - Goo

/// Island + neck + blob as a metaball (blur and threshold), black at the
/// island and through the drop (the stage turns the drop to glass once it separates). An island's
/// or notch's neck is a smooth hourglass going in, and the drop is drawn crisp
/// on top so the black meets the orb's edge exactly.
struct IslandGooCanvas: View {
    let controller: IslandMorphController
    let frame: IslandMorphController.Frame

    /// Room above the screen so the blur and the notch overhang are not cut off.
    private static let topMargin: CGFloat = 60

    /// The neck's fillet radius at full width. It shrinks with the neck as it
    /// thins, so the neck pinches off to nothing.
    static let maxFilletRadius: CGFloat = 14
    /// How far past the cutout's flat bottom, onto its rounded corner, the
    /// fillets may reach: there the edge has risen by a tenth of a point.
    static let filletCurveAllowance: CGFloat = 2

    /// The neck's outline and the fillet radius it was drawn with.
    struct NeckOutline {
        var path: Path
        var filletRadius: CGFloat
    }

    /// The neck between the cutout's bottom edge (`junction`) and the drop,
    /// with exact edges: its sides leave the junction along quarter circles
    /// tangent to it and run into the drop along circles tangent to its
    /// outline, so there's no corner anywhere and the black meets the orb's
    /// edge exactly. A long neck is a rod `waist` wide with a fillet at each
    /// end; a short one is a single fillet from the edge into the drop. Each
    /// side meets the junction no more than `reach` from the center, and a
    /// block up to `tuckTop` fuses it into the cutout. Nil once the neck has
    /// pinched off.
    static func neckOutline(centerX cx: CGFloat, junction: CGFloat, tuckTop: CGFloat,
                            blob: IslandMorphController.Frame, waist: CGFloat,
                            reach: CGFloat) -> NeckOutline? {
        let radius = blob.diameter / 2
        let center = blob.center
        // How far the drop's center is below the junction.
        let depth = center.y - junction
        // How far the drop pokes out of the cutout. Tucked inside, there is no neck.
        let protrusion = depth + radius
        guard waist > 0.01, radius > 0, protrusion > 0.01 else { return nil }
        let halfWaist = min(waist / 2, radius * 0.9)
        // The fillets grow from nothing as the drop comes out, so the neck
        // never hangs below the cutout's edge ahead of the drop.
        let emerged = min(1, protrusion / radius)
        var fillet = max(0, min(maxFilletRadius * min(1, waist / IslandMorphController.neckWidth) * emerged,
                                reach - halfWaist))
        // Horizontal offset of a fillet circle tangent to the junction and to
        // the drop, if one exists.
        func tangentOffset(_ r: CGFloat) -> CGFloat? {
            let s = (radius + r) * (radius + r) - (depth - r) * (depth - r)
            return s >= 0 ? s.squareRoot() : nil
        }
        // A drop close to the edge spreads the fillet wider: keep it on the cutout.
        if let offset = tangentOffset(fillet), offset > reach {
            fillet = max(0, (reach * reach + depth * depth - radius * radius) / (2 * (radius + depth)))
        }
        let offset = tangentOffset(fillet)

        func arc(_ c: CGPoint, _ r: CGFloat, from a0: Double, to a1: Double) -> [CGPoint] {
            let steps = 16
            return (0...steps).map { i in
                let a = a0 + (a1 - a0) * Double(i) / Double(steps)
                return CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            }
        }
        func pointOnDrop(toward p: CGPoint) -> CGPoint {
            let d = max(hypot(p.x - center.x, p.y - center.y), 0.001)
            return CGPoint(x: center.x + radius * (p.x - center.x) / d,
                           y: center.y + radius * (p.y - center.y) / d)
        }
        func angle(_ from: CGPoint, _ to: CGPoint) -> Double { atan2(to.y - from.y, to.x - from.x) }

        // The right side, from the junction down into the drop.
        var side: [CGPoint]
        let usesRod = depth >= fillet && (offset.map { $0 <= halfWaist + fillet } ?? true)
        if usesRod {
            let top = CGPoint(x: cx + halfWaist + fillet, y: junction + fillet)
            side = arc(top, fillet, from: -.pi / 2, to: -.pi)
            let rise = ((radius + fillet) * (radius + fillet) - (halfWaist + fillet) * (halfWaist + fillet))
                .squareRoot()
            let bottom = CGPoint(x: top.x, y: max(center.y - rise, top.y))
            side += arc(bottom, fillet, from: .pi, to: angle(bottom, pointOnDrop(toward: bottom)))
        } else if let offset {
            let c = CGPoint(x: cx + offset, y: junction + fillet)
            var end = angle(c, pointOnDrop(toward: c))
            if end > -.pi / 2 { end -= 2 * .pi }
            side = arc(c, fillet, from: -.pi / 2, to: end)
        } else {
            return nil
        }

        let left = side.reversed().map { CGPoint(x: 2 * cx - $0.x, y: $0.y) }
        let tuck = min(tuckTop, junction)
        // One closed outline: `addLines` would start a new subpath at each side.
        let outline = [CGPoint(x: side[0].x, y: tuck)] + side
            + [CGPoint(x: cx, y: max(center.y, side[side.count - 1].y))]
            + left + [CGPoint(x: left[left.count - 1].x, y: tuck)]
        var path = Path()
        path.move(to: outline[0])
        for point in outline.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return NeckOutline(path: path, filletRadius: fillet)
    }

    var body: some View {
        let placement = controller.placement
        let island = placement.island
        let margin = Self.topMargin
        let isBezel = island.kind == .bezel
        let rodWidth = controller.neckRodWidth
        let blobTop = frame.center.y - frame.diameter / 2
        let connected = controller.neckConnected
        // Island and notch: a smooth hourglass from the cutout into the drop.
        // It thins with the rod, and once its waist is narrower than the blur
        // can hold the threshold parts it, leaving a drip on the cutout and a
        // peak on the drop that recoil as the neck keeps thinning.
        // Past the snap: how far the drip and the peak have recoiled, 0...1.
        let snapGap = IslandMorphController.snapGap(base: controller.neckBase, reach: controller.currentNeckReach)
        let recoil: Double? = isBezel || controller.neckGap <= snapGap ? nil : Easing.clamp01(Double(
            (controller.neckGap - snapGap)
                / (IslandMorphController.neckReach * IslandMorphController.neckBreakWidth / controller.neckBase)))
        // Past the snap the neck keeps thinning, so the threshold parts it over
        // several frames rather than all at once; it goes a little faster
        // than the rod so its ends don't linger as needle points, and the
        // round nubs take over the remnants.
        let neckWaist = recoil.map { rodWidth * CGFloat(1 - Easing.smoothstep(0, 0.5, $0)) } ?? rodWidth
        let neck = isBezel ? nil : Self.neckOutline(
            centerX: frame.center.x,
            // Tangent to the drawn bottom edge, a point inside the hardware.
            junction: island.drawnBottom,
            tuckTop: island.drawnBottom - 14,
            blob: frame,
            waist: neckWaist,
            reach: island.drawnFlatHalfWidth + Self.filletCurveAllowance
        )
        // Solid black through the neck's fillets before the fade begins, so
        // the join reads as one shape with the cutout; a point or two of
        // mismatch with the hardware then shows as more neck, not as grey.
        // Follows the rod (continuous through the snap) and how far the drop
        // is out of the cutout, never the drawn outline, which hands over to
        // the remnants at the snap: the fade's top must not jump with it.
        let protrusion = frame.center.y + frame.diameter / 2 - island.drawnBottom
        let solidDepth = isBezel ? 0
            : (Self.maxFilletRadius * min(1, rodWidth / IslandMorphController.neckWidth) + 4)
                * min(1, max(0, protrusion) / max(frame.diameter / 2, 1))
        let fadeStart = island.drawnBottom + solidDepth
        // Clear by the blob's upper third while the neck holds, over a stretch
        // long enough to read as a melt; as the neck thins and snaps the fade
        // pulls up to the blob's top so no gray wedge of blob is left on the orb.
        // The whole drop is island-black in both schemes (the stage
        // cross-fades it into the glass as the neck thins).
        let fadeEnd = blobTop + frame.diameter * 3

        GeometryReader { geo in
            let height = geo.size.height + margin
            Canvas { ctx, size in
                ctx.translateBy(x: 0, y: margin)
                let blob = CGRect(x: frame.center.x - frame.diameter / 2,
                                  y: blobTop, width: frame.diameter, height: frame.diameter)
                ctx.drawLayer { goo in
                // Later filters run first: blur, then threshold. The threshold
                // gives the metaball its hard silhouette.
                goo.addFilter(.alphaThreshold(min: 0.5, color: .black))
                goo.addFilter(.blur(radius: isBezel ? IslandMorphController.blur : IslandMorphController.cutoutBlur))
                goo.drawLayer { layer in
                    layer.fill(island.path(screenWidth: placement.screenWidth), with: .color(.black))
                    if isBezel, rodWidth > 0.5 {
                        // A straight-sided U down to the drop's middle, where
                        // the drop's own curve rounds it off.
                        let top = island.drawnBottom - 14
                        let bottom = max(frame.center.y, top + 1)
                        let rod = CGRect(x: frame.center.x - rodWidth / 2, y: top,
                                         width: rodWidth, height: bottom - top)
                        layer.fill(Rectangle().path(in: rod), with: .color(.black))
                    }
                    if let neck {
                        layer.fill(neck.path, with: .color(.black))
                    }
                    if let recoil, recoil < 1 {
                        // Round nubs under the thinning neck, so its ends recoil
                        // as a rounded drip under the cutout and a rounded peak
                        // on the drop rather than needle points.
                        let r = Self.remnantRadius
                        // They start just far enough apart for the threshold to
                        // part them, so the split shows at the snap itself.
                        let start = min(Self.remnantHeight, max(0, (snapGap - Self.remnantParting) / 2))
                        let height = start * CGFloat(1 - Easing.smoothstep(0, 1, recoil))
                        let drip = CGRect(x: frame.center.x - r, y: island.drawnBottom + height - 2 * r,
                                          width: 2 * r, height: 2 * r)
                        let peak = CGRect(x: frame.center.x - r, y: blobTop - height,
                                          width: 2 * r, height: 2 * r)
                        layer.fill(Circle().path(in: drip), with: .color(.black))
                        layer.fill(Circle().path(in: peak), with: .color(.black))
                    }
                    if isBezel {
                        // The flared shoulders: a shallow ellipse on the edge that
                        // the blur melts into the neck. It grows as the drop pokes
                        // into the screen and recoils as the neck thins.
                        let radius = min(frame.diameter, IslandMorphController.pullRadiusEnd * 2) / 2
                        let protrusion = max(0, frame.center.y + frame.diameter / 2 - island.drawnBottom)
                        let depth = min(protrusion * IslandMorphController.bezelShoulderDepth, radius)
                            * CGFloat(connected)
                        let halfWidth = radius * IslandMorphController.bezelShoulderSpread * CGFloat(connected)
                        if depth > 0.5 {
                            let shoulders = CGRect(x: frame.center.x - halfWidth, y: island.drawnBottom - depth,
                                                   width: halfWidth * 2, height: depth * 2)
                            layer.fill(Ellipse().path(in: shoulders), with: .color(.black))
                        }
                    }
                    // The threshold pulls a blurred circle in by about blur² / 2r:
                    // drawn that much larger, the drop comes out at its own size.
                    // Only once it leaves the cutout: tucked inside, the larger
                    // drop would bulge under the island's bottom edge.
                    let emerged = Easing.clamp01(Double(
                        (frame.center.y + frame.diameter / 2 - island.drawnBottom) / max(frame.diameter / 2, 1)))
                    let grow = isBezel ? 0 : Self.thresholdShrink(radius: frame.diameter / 2) * CGFloat(emerged)
                    layer.fill(Circle().path(in: blob.insetBy(dx: -grow, dy: -grow)), with: .color(.black))
                }
                }
                if !isBezel {
                    // The drop itself, crisp, so the black meets the orb's edge exactly.
                    ctx.fill(Circle().path(in: blob), with: .color(.black))
                }
            }
            .frame(width: geo.size.width, height: height)
            .mask(
                LinearGradient(
                    stops: Self.fadeStops(from: (fadeStart + margin) / height, to: (fadeEnd + margin) / height),
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: -margin)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The nubs the neck leaves when it snaps: their radius, and how far they
    /// stand out from the cutout and the drop at first.
    static let remnantRadius: CGFloat = 9
    static let remnantHeight: CGFloat = 9
    /// The gap between two such nubs at which the blur no longer joins them
    /// (about 1.35 blur radii).
    static let remnantParting: CGFloat = 8

    /// How far blur and threshold pull in the edge of a circle of `radius`,
    /// capped for small drops where the approximation runs away.
    static func thresholdShrink(radius: CGFloat) -> CGFloat {
        let blur = IslandMorphController.cutoutBlur
        return min(blur * blur / (2 * max(radius, 1)), blur / 2)
    }

    /// Solid to `start`, clear from `end`, eased in between (smoothstep) so the
    /// black melts away without the hard bands a linear ramp shows at its ends.
    static func fadeStops(from start: CGFloat, to end: CGFloat) -> [Gradient.Stop] {
        let start = Double(start), end = max(Double(end), Double(start) + 0.0001)
        let steps = 8
        var stops: [Gradient.Stop] = [.init(color: .black, location: 0)]
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            stops.append(.init(color: .black.opacity(1 - Easing.smoothstep(0, 1, t)),
                               location: start + (end - start) * t))
        }
        stops.append(.init(color: .clear, location: max(1, end)))
        return stops
    }
}
