//
//  IslandMorph.swift
//  Palettes
//
//  The Dynamic Island (or notch) to orb morph. The island, a stretching neck
//  and a blob are drawn as a metaball in a `Canvas` (blur + alpha threshold),
//  and the goo is masked so only the part near the island is black: it melts
//  into the real, clear glass orb, which is drawn at the blob's frame from the
//  first point of the pull. Nothing about the orb is ever black or grey.
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
    static let pullTravelRatio: CGFloat = 0.85
    /// Width of the neck rod when the blob touches the island, and the width below
    /// which the blurred rod falls under the alpha threshold: the neck has snapped.
    static let neckWidth: CGFloat = 34
    static let neckBreakWidth: CGFloat = 12
    static let neckReach: CGFloat = 52
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
        let r = Easing.lerp(island.drawnHeight / 2, Self.pullRadiusEnd,
                            Easing.clamp01(d / Self.pullRadiusRamp))
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
    var neckRodWidth: CGFloat { Self.neckRodWidth(gap: neckGap, base: neckBase) }

    /// Width of the rod bridging island and blob: full while they touch,
    /// thinning as they part.
    static func neckRodWidth(gap: CGFloat, base: CGFloat = neckWidth) -> CGFloat {
        guard gap > 0 else { return base }
        return max(0, base * (1 - gap / neckReach))
    }

    /// The gap at which the blurred rod drops under the threshold and snaps.
    static func snapGap(base: CGFloat = neckWidth) -> CGFloat {
        neckReach * (1 - neckBreakWidth / base)
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
        let rod = Self.neckRodWidth(gap: neckGap, base: base)
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

    /// Dark stage only: how far the island-black drop has turned into clear
    /// glass. It stays black while joined (the glass rim would read as a
    /// circle against the black neck) and from the moment it separates eases
    /// into glass over most of the remaining travel, so the change is one
    /// long, even dissolve rather than a swap.
    var darkGlassReveal: Double {
        guard mode == .morph, placement.island.kind != .none, phase != .landed else { return 1 }
        guard phase == .detaching, neckConnected <= 0.001, let start = separatedAt else { return 0 }
        return Easing.smoothstep(start, max(start + 0.2, min(start + 0.7, 0.98)), Easing.clamp01(detach.value))
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
        let snapGap = Self.snapGap(base: neckBase)
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
        // Dark stage: the black drop dissolves into glass after it separates.
        // Light mode blends on its own.
        let dark = colorScheme == .dark && !fade
        let glassReveal = dark ? controller.darkGlassReveal : 1
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
    @Environment(\.colorScheme) private var colorScheme
}

// MARK: - Goo

/// Island + neck + blob as a metaball, faded from black at the island to clear
/// at the blob so the orb never reads as black.
struct IslandGooCanvas: View {
    let controller: IslandMorphController
    let frame: IslandMorphController.Frame
    @Environment(\.colorScheme) private var colorScheme

    /// Room above the screen so the blur and the notch overhang are not cut off.
    private static let topMargin: CGFloat = 60

    /// The neck's fillet radius where it meets the island at full width. It
    /// shrinks with the neck as it thins, and on a small island it's capped so
    /// the flare stays under the island's flat bottom (give or take a point of
    /// its curve, which the junction's tuck hides).
    static let maxFilletRadius: CGFloat = 14

    static func filletRadius(island: IslandGeometry, rodWidth: CGFloat) -> CGFloat {
        let scaled = maxFilletRadius * min(1, rodWidth / IslandMorphController.neckWidth)
        guard island.kind == .dynamicIsland else { return scaled }
        let drawnWidth = island.width - 2 * IslandGeometry.drawInset
        let room = (drawnWidth - rodWidth) / 2 - 6
        return max(0, min(scaled, room))
    }

    /// A rod `width` wide from `junction` down to `bottom`, its top corners
    /// flared out by quarter circles of `radius` so it meets the island's
    /// bottom edge tangentially, plus a block up to `tuckTop` that fuses it
    /// into the island.
    static func filletedNeck(centerX: CGFloat, junction: CGFloat, tuckTop: CGFloat,
                             bottom: CGFloat, width: CGFloat, radius: CGFloat) -> Path {
        let left = centerX - width / 2
        let right = centerX + width / 2
        let flare = radius + 1
        var path = Path()
        path.move(to: CGPoint(x: right + flare, y: junction))
        path.addArc(tangent1End: CGPoint(x: right, y: junction),
                    tangent2End: CGPoint(x: right, y: bottom), radius: radius)
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.addLine(to: CGPoint(x: left, y: bottom))
        path.addArc(tangent1End: CGPoint(x: left, y: junction),
                    tangent2End: CGPoint(x: left - flare, y: junction), radius: radius)
        path.addLine(to: CGPoint(x: left - flare, y: junction))
        path.addLine(to: CGPoint(x: left - flare, y: min(tuckTop, junction)))
        path.addLine(to: CGPoint(x: right + flare, y: min(tuckTop, junction)))
        path.closeSubpath()
        return path
    }

    var body: some View {
        let placement = controller.placement
        let island = placement.island
        let margin = Self.topMargin
        let rodWidth = controller.neckRodWidth
        let blobTop = frame.center.y - frame.diameter / 2
        // Solid black through the neck's fillets before the fade begins, so
        // the join reads as one shape with the cutout; a point or two of
        // mismatch with the hardware then shows as more neck, not as grey.
        let solidDepth = island.kind == .bezel
            ? 0 : Self.filletRadius(island: island, rodWidth: rodWidth) + 4
        let fadeStart = island.drawnBottom + solidDepth
        // Clear by the blob's upper third while the neck holds; as it thins and snaps the
        // fade pulls up to the blob's top so no gray wedge of blob is left on the orb.
        let connected = controller.neckConnected
        // Dark stage: the whole drop is island-black (the stage cross-fades it
        // into the glass as the neck thins).
        let fadeEnd = colorScheme == .dark
            ? blobTop + frame.diameter * 3
            : max(blobTop + frame.diameter / 3 * CGFloat(connected), fadeStart + 10)

        GeometryReader { geo in
            let height = geo.size.height + margin
            Canvas { ctx, size in
                ctx.translateBy(x: 0, y: margin)
                // Later filters run first: blur, then threshold. The threshold
                // gives the metaball its hard silhouette.
                ctx.addFilter(.alphaThreshold(min: 0.5, color: .black))
                ctx.addFilter(.blur(radius: IslandMorphController.blur))
                ctx.drawLayer { layer in
                    layer.fill(island.path(screenWidth: placement.screenWidth), with: .color(.black))
                    if rodWidth > 0.5 {
                        let top = island.drawnBottom - 14
                        if island.kind == .bezel {
                            // A straight-sided U down to the drop's middle, where
                            // the drop's own curve rounds it off.
                            let bottom = max(frame.center.y, top + 1)
                            let rod = CGRect(x: frame.center.x - rodWidth / 2, y: top,
                                             width: rodWidth, height: bottom - top)
                            layer.fill(Rectangle().path(in: rod), with: .color(.black))
                        } else {
                            // Flared into the island with circular fillets, so the
                            // neck meets the cutout in round corners on every
                            // island and notch, rather than the tight, angular
                            // ones the blur alone would leave.
                            let bottom = max(frame.center.y, island.drawnBottom + 1)
                            let path = Self.filletedNeck(
                                centerX: frame.center.x,
                                junction: island.drawnBottom - 1,
                                tuckTop: top,
                                bottom: bottom,
                                width: rodWidth,
                                radius: Self.filletRadius(island: island, rodWidth: rodWidth)
                            )
                            layer.fill(path, with: .color(.black))
                        }
                    }
                    if island.kind == .bezel {
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
                    let blob = CGRect(x: frame.center.x - frame.diameter / 2,
                                      y: blobTop, width: frame.diameter, height: frame.diameter)
                    layer.fill(Circle().path(in: blob), with: .color(.black))
                }
            }
            .frame(width: geo.size.width, height: height)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: Double((fadeStart + margin) / height)),
                        .init(color: .clear, location: Double((fadeEnd + margin) / height)),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .offset(y: -margin)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
