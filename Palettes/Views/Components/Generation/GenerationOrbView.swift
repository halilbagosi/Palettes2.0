//
//  GenerationOrbView.swift
//  Palettes
//

import SwiftUI
import Combine

/// An embeddable clear liquid glass orb. Colors materialize inside it as soft
/// drops of liquid that drift and mingle; an optional prompt, photo, and
/// progress dots render inside the glass. Dragging stretches the orb toward
/// the finger like pulled liquid and it springs back on release.
struct GenerationOrbView: View {
    var colors: [Color] = []
    var promptText: String? = nil
    var photo: UIImage? = nil
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
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let t = reduceMotion ? 0.0 : now.timeIntervalSince(startDate)

            ZStack {
                liquid(diameter: diameter, time: t, now: now)
                    .clipShape(Circle())

                // Clear glass shell — refracts whatever sits behind the orb
                Circle()
                    .fill(.clear)
                    .liquidGlass(.clear, in: .circle)
                    .frame(width: diameter, height: diameter)

                // Drawn above the liquid so it stays readable as colors arrive
                innerContent(diameter: diameter)
            }
            .frame(width: diameter, height: diameter)
        }
        .scaleEffect(
            x: 1 + abs(squish.width) * malleability - abs(squish.height) * crossThin,
            y: 1 + abs(squish.height) * malleability - abs(squish.width) * crossThin,
            anchor: stretchAnchor
        )
        .offset(x: dragOffset.width * translation, y: dragOffset.height * translation)
        .contentShape(Circle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.45)) {
                        dragOffset = .zero
                    }
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
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: diameter * 0.24, height: diameter * 0.24)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                    .transition(.scale.combined(with: .opacity))
            }

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

    // Deformation constants, tuned via the (now removed) live debug panel.
    /// How far the orb stretches toward the finger.
    private let malleability: CGFloat = 0.50
    /// How much the orb thins on the axis perpendicular to the stretch.
    private let crossThin: CGFloat = 0.00
    /// Inner-content refraction intensity.
    private let warpStrength: CGFloat = 0.00
    /// 0 = stretch from center, 1 = anchored fully on the side opposite the drag.
    private let anchorStrength: CGFloat = 1.00
    /// Residual whole-orb translation per point of drag.
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

    private func liquid(diameter: CGFloat, time t: Double, now: Date) -> some View {
        ZStack {
            // Faint neutral swirl while the orb is still empty
            if colors.isEmpty {
                Circle()
                    .fill(Color.secondary.opacity(0.10))
                    .frame(width: diameter * 0.5, height: diameter * 0.5)
                    .offset(drift(index: 0, time: t, orbit: diameter * 0.14))
                    .blur(radius: diameter * 0.08)
            }

            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                let bloom = bloomProgress(for: index, at: now)
                Circle()
                    .fill(color.opacity(0.7))
                    .frame(width: diameter * 0.52, height: diameter * 0.52)
                    .offset(drift(index: index, time: t, orbit: diameter * 0.19))
                    .scaleEffect(bloom)
                    .opacity(Double(bloom))
            }
        }
        .blur(radius: diameter * 0.07)
        .saturation(1.2)
        // Slosh: the liquid lags slightly behind the glass while stretching
        .offset(x: warpShift.width * -0.15, y: warpShift.height * -0.15)
        .frame(width: diameter, height: diameter)
    }

    /// Slow orbital drift, unique per drop.
    private func drift(index: Int, time t: Double, orbit: CGFloat) -> CGSize {
        let i = Double(index)
        let speed = 0.55 + 0.06 * i.truncatingRemainder(dividingBy: 3)
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
