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
    private var release = Frame(center: .zero, diameter: 0)
    private var isSnapped = false
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
            center: CGPoint(x: placement.screenWidth / 2,
                            y: island.drawnBottom - r + d * Self.pullTravelRatio),
            diameter: r * 2
        )
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

    /// Width of the rod bridging island and blob: full while they touch,
    /// thinning as they part.
    static func neckRodWidth(gap: CGFloat) -> CGFloat {
        guard gap > 0 else { return neckWidth }
        return max(0, neckWidth * (1 - gap / neckReach))
    }

    /// The gap at which the blurred rod drops under the threshold and snaps.
    static var snapGap: CGFloat { neckReach * (1 - neckBreakWidth / neckWidth) }

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

    /// Whether the island goo is on screen. It exists only while pulling and detaching.
    var showsGoo: Bool {
        mode == .morph && placement.island.hasMorph && phase != .landed
    }

    // MARK: Gesture

    /// `time` is the touch event's timestamp (seconds), not the time it was handled:
    /// updates delivered in a batch must not look instantaneous.
    func dragChanged(translation: Double, time: TimeInterval) {
        guard mode == .morph, placement.island.hasMorph else { return }
        if phase == .detaching || phase == .landed { return }
        if phase != .dragging {
            // Grab: pick up wherever the blob is (it may still be retracting).
            pull.freeze()
            virtualStart = OnboardingPull.inverseRubberBand(pull.value)
            phase = .dragging
            rigid.prepare()
            soft.prepare()
        }
        pull.track(OnboardingPull.rubberBand(virtualStart + translation), at: time)
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
        onCommit?()
        detach.jump(to: 0)
        detach.animate(to: 1, response: 0.6, dampingFraction: 0.86, initialVelocity: normalised)
    }

    /// Fades the orb in at its resting place: no island, Reduce Motion, VoiceOver.
    func beginFade() {
        guard phase == .idle || phase == .dragging else { return }
        mode = .fade
        phase = .detaching
        onCommit?()
        detach.jump(to: 0)
        detach.animate(to: 1, response: 0.5, dampingFraction: 1)
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

    // MARK: Events

    /// Fires the rigid haptic on the frame the neck actually snaps (and rearms
    /// when it re-forms on a retract).
    private func evaluateNeck() {
        guard mode == .morph else { return }
        let gap = neckGap
        if !isSnapped, gap >= Self.snapGap {
            isSnapped = true
            if phase != .landed { rigid.impactOccurred(intensity: 0.7) }
        } else if isSnapped, gap < Self.snapGap - 6 {
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
    /// Receives the orb's current diameter.
    @ViewBuilder var orb: (CGFloat) -> Orb

    init(controller: IslandMorphController, @ViewBuilder orb: @escaping (CGFloat) -> Orb) {
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
        ZStack {
            OrbHalo(diameter: frame.diameter)
                .position(frame.center)
                .opacity(controller.orbOpacity)
            orb(frame.diameter)
                .scaleEffect(fadeScale)
                .blur(radius: fadeBlur)
                .opacity(controller.orbOpacity)
                .position(frame.center)
            // The goo sits above the glass: the island's black covers the part of
            // the orb still tucked behind it (so clear glass is never drawn over the
            // cutout, where it would read dark), and the neck's fade overlaps the
            // orb's top as black melting into glass.
            if controller.showsGoo {
                IslandGooCanvas(controller: controller, frame: frame)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(controller.phase == .landed || fade)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

// MARK: - Goo

/// Island + neck + blob as a metaball, faded from black at the island to clear
/// at the blob so the orb never reads as black.
struct IslandGooCanvas: View {
    let controller: IslandMorphController
    let frame: IslandMorphController.Frame

    /// Room above the screen so the blur and the notch overhang are not cut off.
    private static let topMargin: CGFloat = 60

    var body: some View {
        let placement = controller.placement
        let island = placement.island
        let margin = Self.topMargin
        let gap = controller.neckGap
        let rodWidth = IslandMorphController.neckRodWidth(gap: gap)
        let blobTop = frame.center.y - frame.diameter / 2
        let fadeStart = island.drawnBottom
        // Clear by the blob's upper third while the neck holds; as it thins and snaps the
        // fade pulls up to the blob's top so no gray wedge of blob is left on the orb.
        let connected = Easing.clamp01(Double(
            (rodWidth - IslandMorphController.neckBreakWidth)
            / (IslandMorphController.neckWidth - IslandMorphController.neckBreakWidth)))
        let fadeEnd = max(blobTop + frame.diameter / 3 * CGFloat(connected), fadeStart + 10)

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
                        let bottom = max(blobTop + 14, top + 1)
                        let rod = CGRect(x: frame.center.x - rodWidth / 2, y: top,
                                         width: rodWidth, height: bottom - top)
                        layer.fill(Capsule().path(in: rod), with: .color(.black))
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
