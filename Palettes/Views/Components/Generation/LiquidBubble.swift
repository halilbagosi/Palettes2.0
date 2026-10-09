//
//  LiquidBubble.swift
//  Palettes
//
//  A clear water bubble of Liquid Glass that wobbles like a water balloon:
//  it keeps squashing into ellipses whose axis slowly turns, and a kick makes
//  it jiggle and settle. Content placed inside is seen through the water: it
//  bends and wraps around the rim. A soft glow sits behind it.
//
//  Used by the generation orb and the onboarding orb.
//

import SwiftUI

// MARK: - Wobble model

/// The bubble's shape at one moment: a circle deformed by an oval (mode 2) and
/// a slight three-lobed (mode 3) wave, plus a small drift of its center.
struct BubbleWobble: Equatable {
    var oval: Double = 0
    var ovalAngle: Double = 0
    var lobe: Double = 0
    var lobeAngle: Double = 0
    var drift: CGSize = .zero

    static let still = BubbleWobble()

    /// - Parameters:
    ///   - t: seconds since the bubble appeared.
    ///   - energy: idle liveliness, 0 (still) to 1 (busy, like while generating).
    ///   - sinceKick: seconds since the last kick, or nil if none yet.
    static func at(_ t: Double, energy: Double, sinceKick: Double?) -> BubbleWobble {
        // Idle: a slow breathing oval whose axis keeps turning, with an
        // amplitude that itself swells and relaxes so it never looks looped.
        let swell = 0.5 + 0.5 * sin(t * 0.47 + 1.3) * sin(t * 0.29)
        var oval = energy * (0.025 + 0.09 * swell) * sin(t * 1.9)
        var angle = t * 0.55 + 0.9 * sin(t * 0.31)
        var lobe = energy * 0.02 * sin(t * 2.7 + 0.6)
        let lobeAngle = -t * 0.4

        // Kick: a damped jiggle on top, like a water balloon that was poked.
        if let k = sinceKick, k >= 0, k < 2.5 {
            let decay = exp(-2.1 * k)
            oval += 0.16 * decay * cos(k * 10.5)
            lobe += 0.05 * decay * sin(k * 13.0)
            angle += 0.4 * decay
        }

        let drift = CGSize(width: energy * 0.018 * sin(t * 0.8 + 0.4),
                           height: energy * 0.022 * sin(t * 0.63))
        return BubbleWobble(oval: oval, ovalAngle: angle, lobe: lobe, lobeAngle: lobeAngle, drift: drift)
    }
}

/// The bubble outline for a wobble state, fitted to the rect's inscribed circle.
struct BubbleShape: Shape {
    var wobble: BubbleWobble

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX + wobble.drift.width * r * 2,
                        y: rect.midY + wobble.drift.height * r * 2)
        let n = 96
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        for i in 0..<n {
            let th = Double(i) / Double(n) * 2 * .pi
            let k = 1 + wobble.oval * cos(2 * (th - wobble.ovalAngle))
                      + wobble.lobe * cos(3 * (th - wobble.lobeAngle))
            points.append(CGPoint(x: c.x + r * k * cos(th), y: c.y + r * k * sin(th)))
        }
        // Smooth closed curve through the midpoints.
        var path = Path()
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        path.move(to: mid(points[n - 1], points[0]))
        for i in 0..<n {
            path.addQuadCurve(to: mid(points[i], points[(i + 1) % n]), control: points[i])
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Bubble

struct LiquidBubble<Content: View>: View {
    var diameter: CGFloat
    /// Idle liveliness: 0 still, ~0.4 resting, 1 busy.
    var energy: Double = 0.4
    /// Change this to poke the bubble (it jiggles and settles).
    var kick: Int = 0
    /// How strongly content bends toward the rim, 0...1.
    var lensStrength: Double = 0.9
    var showsGlow: Bool = true
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()
    @State private var kickDate: Date?

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let since = kickDate.map { timeline.date.timeIntervalSince($0) }
            let wobble = reduceMotion ? .still : BubbleWobble.at(t, energy: energy, sinceKick: since)
            bubble(wobble)
        }
        .frame(width: diameter, height: diameter)
        .onChange(of: kick) { _, _ in kickDate = Date() }
    }

    private func bubble(_ w: BubbleWobble) -> some View {
        let shape = BubbleShape(wobble: w)
        let r = diameter / 2
        let center = CGPoint(x: r + w.drift.width * diameter, y: r + w.drift.height * diameter)
        // The lens follows the current oval.
        let radii = CGSize(width: r * (1 + abs(w.oval)), height: r * (1 - abs(w.oval)))
        let lensAngle = w.oval >= 0 ? w.ovalAngle : w.ovalAngle + .pi / 2

        return ZStack {
            if showsGlow {
                if colorScheme == .dark {
                    backdrop(shape)
                        .offset(x: w.drift.width * diameter, y: w.drift.height * diameter)
                } else {
                    lightShadow(shape)
                }
            }
            if colorScheme != .dark { lightBody(shape) }

            content()
                .frame(width: diameter, height: diameter)
                .distortionEffect(
                    ShaderLibrary.bubbleLens(
                        .float2(Float(center.x), Float(center.y)),
                        .float2(Float(radii.width), Float(radii.height)),
                        .float(Float(lensAngle)),
                        .float(Float(lensStrength))
                    ),
                    maxSampleOffset: CGSize(width: r, height: r)
                )
                .clipShape(shape)

            glass(shape)
        }
        .frame(width: diameter, height: diameter)
    }

    /// Dark stage: a soft white glow around the bubble only, so the water
    /// itself stays dark and clear.
    private func backdrop(_ shape: BubbleShape) -> some View {
        Circle()
                .fill(RadialGradient(
                    colors: [Color.white.opacity(0.2), .clear],
                    center: .center, startRadius: diameter * 0.45, endRadius: diameter * 0.95))
                .frame(width: diameter * 2.3, height: diameter * 2.3)
                .mask {
                    Rectangle()
                        .overlay { shape.fill(.black).frame(width: diameter, height: diameter).blendMode(.destinationOut) }
                        .compositingGroup()
                        .frame(width: diameter * 2.3, height: diameter * 2.3)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
    }

    /// Light stage: a large soft grey shadow all around, like a drop of water
    /// resting just above white paper.
    private func lightShadow(_ shape: BubbleShape) -> some View {
        shape
            .fill(.black.opacity(0.16))
            .frame(width: diameter, height: diameter)
            .scaleEffect(1.04)
            .blur(radius: diameter * 0.09)
            .offset(y: diameter * 0.035)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Light stage: the water reads as a white jelly, a touch brighter in the
    /// middle, with a faint grey crescent inside the lower rim for thickness.
    private func lightBody(_ shape: BubbleShape) -> some View {
        ZStack {
            shape.fill(RadialGradient(colors: [.white, Color(white: 0.955)],
                                      center: .init(x: 0.45, y: 0.4),
                                      startRadius: 0, endRadius: diameter * 0.55))
            shape
                .stroke(.black.opacity(0.07), lineWidth: diameter * 0.14)
                .blur(radius: diameter * 0.06)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0.45),
                                             .init(color: .black, location: 1)],
                                     startPoint: .topTrailing, endPoint: .bottomLeading))
                .clipShape(shape)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Drawn glass rather than the system material: the system's clear glass
    /// frosts what's inside, while a water bubble stays perfectly clear and only
    /// its edge catches the light.
    private func glass(_ shape: BubbleShape) -> some View {
        let dark = colorScheme == .dark
        let d = diameter
        return ZStack {
            // Edge thickness: a soft band of light just inside the rim, the way
            // the wall of a bubble looks brighter where you see it edge-on.
            shape
                .stroke(.white.opacity(dark ? 0.22 : 0.45), lineWidth: d * 0.07)
                .blur(radius: d * 0.035)
                .clipShape(shape)

            // A faint darker line outside the rim keeps the edge legible on a light stage.
            if !dark {
                shape.stroke(.black.opacity(0.07), lineWidth: 1.5).blur(radius: 1)
            }

            // Crisp rim, brightest where the light comes from.
            shape.stroke(
                AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0.95), location: 0.0),
                        .init(color: .white.opacity(0.25), location: 0.22),
                        .init(color: .white.opacity(0.10), location: 0.45),
                        .init(color: .white.opacity(0.55), location: 0.62),
                        .init(color: .white.opacity(0.20), location: 0.80),
                        .init(color: .white.opacity(0.95), location: 1.0),
                    ],
                    center: .center, angle: .degrees(-135)),
                lineWidth: 1.1)

            // Specular sheen across the top-left of the wall.
            shape
                .stroke(.white.opacity(dark ? 0.55 : 0.8), lineWidth: d * 0.018)
                .blur(radius: d * 0.012)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0),
                                             .init(color: .clear, location: 0.38)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(shape)

            // Light refracted through the water, gathering along the bottom rim.
            shape
                .stroke(.white.opacity(dark ? 0.28 : 0.45), lineWidth: d * 0.012)
                .blur(radius: d * 0.01)
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0.7),
                                             .init(color: .black, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .clipShape(shape)
        }
        .frame(width: d, height: d)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Bubble on dark") {
    ZStack {
        Color.black.ignoresSafeArea()
        LiquidBubble(diameter: 260, energy: 1) {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 12).fill(.blue.gradient).frame(width: 60, height: 60)
                Text("Change this scene into full winter, with the lake frozen over")
                    .font(.footnote).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center).frame(width: 190)
            }
        }
    }
    .preferredColorScheme(.dark)
}
