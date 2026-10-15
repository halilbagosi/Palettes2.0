//
//  GenerationOrbView.swift
//  Palettes
//

import SwiftUI

/// An embeddable clear liquid glass orb. Colors materialize inside it as soft
/// drops of liquid that drift and mingle; an optional prompt and
/// progress dots render inside the glass. Dragging stretches the orb toward
/// the finger like pulled liquid and it springs back on release.
struct GenerationOrbView: View {
    var colors: [Color] = []
    var promptText: String? = nil
    var expectedCount: Int = 0
    var showsProgress: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var arrivalTimes: [Date] = []
    @State private var dragOffset: CGSize = .zero

    private let startDate = Date()

    /// The orb fills whatever square fits its proposed size, so an animated
    /// frame (e.g. a matchedGeometryEffect morph) continuously rescales the
    /// glass, liquid, and blur instead of snapping between fixed sizes.
    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            orb(diameter: diameter)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func orb(diameter: CGFloat) -> some View {
        ZStack {
            // Fixed light under the orb; it doesn't move with the drop.
            BubbleStageGlow(diameter: diameter)
            bubble(diameter: diameter)
        }
    }

    private func bubble(diameter: CGFloat) -> some View {
        // A clear water bubble: busy while colors are arriving, calm otherwise,
        // and it jiggles as each color lands or when it is let go after a pull.
        LiquidBubble(diameter: diameter,
                     energy: showsProgress ? 1 : 0.4,
                     kick: colors.count,
                     externalPull: dragOffset) {
            TimelineView(.animation) { timeline in
                let now = timeline.date
                let t = reduceMotion ? 0.0 : now.timeIntervalSince(startDate)

                liquid(diameter: diameter, time: t, now: now)
                    .frame(width: diameter, height: diameter)
            }
        }
        // Text and progress sit on top of the glass so they stay crisp;
        // under it, the glass would frost them.
        .overlay { innerContent(diameter: diameter) }
        // Pulling deforms the drop itself (LiquidBubble's externalPull).
        .contentShape(Circle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    // The bubble springs back with its own jiggle.
                    dragOffset = .zero
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: colors.count)
        .onChange(of: colors.count) { oldCount, newCount in
            if newCount > oldCount {
                arrivalTimes.append(contentsOf: Array(repeating: Date(), count: newCount - oldCount))
            } else if newCount < oldCount {
                arrivalTimes = Array(arrivalTimes.prefix(newCount))
            }
        }
    }

    // MARK: - Inner Content

    @ViewBuilder
    private func innerContent(diameter: CGFloat) -> some View {
        VStack(spacing: 12) {
            if let promptText, !promptText.isEmpty {
                Text(promptText)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: diameter * 0.72)
            }

            if showsProgress, expectedCount > 1 {
                HStack(spacing: 7) {
                    ForEach(0..<expectedCount, id: \.self) { i in
                        Circle()
                            .fill(i < colors.count ? colors[i] : Color.primary.opacity(0.10))
                            .frame(width: 9, height: 9)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: colors.count)
            }
        }
        .frame(width: diameter, height: diameter)
        // The inner elements refract through the glass as the orb is pulled.
        .distortionEffect(
            ShaderLibrary.lensWarp(
                .float2(Float(diameter / 2 + warpShift.width), Float(diameter / 2 + warpShift.height)),
                .float(Float(diameter * 0.5)),
                .float(Float(reduceMotion ? 0 : warpStrength * pullStrength))
            ),
            maxSampleOffset: CGSize(width: 70, height: 70)
        )
        .allowsHitTesting(false)
    }

    // MARK: - Deformation

    /// How far the orb stretches toward the finger.
    private let malleability: CGFloat = 0.40
    /// How much the orb thins on the axis perpendicular to the stretch.
    private let crossThin: CGFloat = 0.01
    /// Inner-content refraction intensity.
    private let warpStrength: CGFloat = 0.31
    /// 0 = stretch from center, 1 = anchored fully on the side opposite the drag.
    private let anchorStrength: CGFloat = 1.00
    /// The far side stays pinned; drag changes shape only, never position.
    private let translation: CGFloat = 0.01

    /// Normalized stretch amount from the current drag, capped so the orb
    /// deforms gently rather than tearing apart.
    private var squish: CGSize {
        CGSize(
            width: max(-1, min(1, dragOffset.width / 300)),
            height: max(-1, min(1, dragOffset.height / 300))
        )
    }

    /// The orb itself never translates — the pull is expressed entirely as a
    /// stretch anchored on the far side. This small shift only feeds the inner
    /// refraction and liquid slosh so they still react to the drag.
    private var warpShift: CGSize {
        CGSize(width: dragOffset.width * 0.06,
               height: dragOffset.height * 0.06)
    }

    /// How hard the orb is being pulled right now, 0…1 — drives inner refraction.
    private var pullStrength: CGFloat {
        min(1, hypot(dragOffset.width, dragOffset.height) / 200)
    }

    /// Anchor the stretch at the side opposite the drag, so the orb elongates
    /// toward the finger while the far side stays in place.
    private var stretchAnchor: UnitPoint {
        UnitPoint(
            x: 0.5 - Double(squish.width) * 0.5 * Double(anchorStrength),
            y: 0.5 - Double(squish.height) * 0.5 * Double(anchorStrength)
        )
    }

    // MARK: - Liquid

    private func liquid(diameter: CGFloat, time rawT: Double, now: Date) -> some View {
        let tune = OrbTuning.live
        let t = rawT * tune.dropSpeed
        return ZStack {
            // Faint neutral swirl while the orb is still empty
            if colors.isEmpty {
                Circle()
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: diameter * 0.5, height: diameter * 0.5)
                    .offset(drift(index: 0, time: t, orbit: diameter * 0.22))
                    .blur(radius: diameter * 0.08)
            }

            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                let bloom = bloomProgress(for: index, at: now)
                Circle()
                    .fill(color.opacity(tune.dropOpacity))
                    .frame(width: diameter * tune.dropSize, height: diameter * tune.dropSize)
                    .offset(drift(index: index, time: t, orbit: diameter * tune.dropOrbit))
                    .scaleEffect(bloom)
                    .opacity(Double(bloom))
            }
        }
        .frame(width: diameter, height: diameter)
        // Anchored in the drop: the colors move and stretch with it as it's pulled.
        .followsBubble(diameter: diameter)
        .blur(radius: diameter * tune.dropBlur)
        .saturation(tune.dropSaturation)
        .frame(width: diameter, height: diameter)
    }

    /// Slow orbital drift, unique per drop.
    private func drift(index: Int, time t: Double, orbit: CGFloat) -> CGSize {
        let i = Double(index)
        let speed = 1.0 + 0.1 * i.truncatingRemainder(dividingBy: 3)
        return CGSize(
            width: orbit * sin(t * speed + i * 2.4),
            height: orbit * cos(t * (speed * 0.8) + i * 1.7)
        )
    }

    /// Scale-in progress for a drop after it arrives (0 → 1 over 0.6s).
    private func bloomProgress(for index: Int, at now: Date) -> CGFloat {
        guard index < arrivalTimes.count else { return 1 }
        if reduceMotion { return 1 }
        let p = min(1, max(0, now.timeIntervalSince(arrivalTimes[index]) / 0.6))
        // Ease out with a slight overshoot so the drop "plops" in
        let eased = 1 - pow(1 - p, 3)
        let overshoot = sin(p * .pi) * 0.08
        return CGFloat(eased + overshoot)
    }
}

#Preview("Empty") {
    GenerationOrbView()
        .frame(width: 340, height: 340)
}

#Preview("Generating") {
    GenerationOrbView(
        colors: [Color(hex: "A95F4D")!, Color(hex: "D98A6C")!, Color(hex: "F5C79A")!],
        promptText: "Warm autumn forest",
        expectedCount: 6,
        showsProgress: true
    )
    .frame(width: 340, height: 340)
}
