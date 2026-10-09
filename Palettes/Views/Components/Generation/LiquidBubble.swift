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
    ///   - kick: the last poke: seconds since it, its strength, and the axis it
    ///     was along; nil if none.
    static func at(_ t: Double, energy: Double,
                   kick: (since: Double, amount: Double, angle: Double)?) -> BubbleWobble {
        // Idle: barely there. A slow breathing oval whose axis turns, so the
        // drop looks alive without ever looking pulled. Big shapes only come
        // from the user pulling on it.
        let swell = 0.5 + 0.5 * sin(t * 0.47 + 1.3) * sin(t * 0.29)
        var oval = energy * (0.006 + 0.014 * swell) * sin(t * 1.6)
        var angle = t * 0.45 + 0.9 * sin(t * 0.31)
        var lobe = energy * 0.004 * sin(t * 2.3 + 0.6)
        let lobeAngle = -t * 0.4

        // Kick: a damped jiggle along the poke's axis, like a water balloon
        // that was let go.
        if let k = kick, k.since >= 0, k.since < 2.5 {
            let decay = exp(-3.2 * k.since)
            let jiggle = k.amount * decay * cos(k.since * 13.0)
            // Blend toward the kick's axis while it is strong.
            let weight = min(1, abs(jiggle) / max(abs(oval) + abs(jiggle), 0.0001))
            angle = angle * (1 - weight) + k.angle * weight
            oval += jiggle
            lobe += k.amount * 0.2 * decay * sin(k.since * 16.0)
        }

        let drift = CGSize(width: energy * 0.004 * sin(t * 0.8 + 0.4),
                           height: energy * 0.005 * sin(t * 0.63))
        return BubbleWobble(oval: oval, ovalAngle: angle, lobe: lobe, lobeAngle: lobeAngle, drift: drift)
    }

    /// Stretch toward a finger pulling at `pull` (points from the center).
    /// The drop elongates along the pull and leans a little after the finger.
    func pulled(by pull: CGSize, diameter: CGFloat) -> BubbleWobble {
        let len = hypot(pull.width, pull.height)
        guard len > 0.5 else { return self }
        // Rubber-banded so it never tears.
        let amount = 0.32 * (1 - exp(-Double(len) / Double(diameter * 0.9)))
        var w = self
        w.oval = amount + oval * 0.3
        w.ovalAngle = atan2(Double(pull.height), Double(pull.width))
        w.drift = CGSize(width: drift.width + pull.width / diameter * 0.06,
                         height: drift.height + pull.height / diameter * 0.06)
        return w
    }

    static func pullAmount(_ pull: CGSize, diameter: CGFloat) -> Double {
        0.32 * (1 - exp(-Double(hypot(pull.width, pull.height)) / Double(diameter * 0.9)))
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
    /// Change this to poke the bubble (a small jiggle that settles).
    var kick: Int = 0
    /// When true the user can grab the drop and pull it out of shape; it
    /// springs back with a jiggle on release.
    var pullable: Bool = false
    /// An external pull (e.g. a parent's own drag gesture), in points.
    var externalPull: CGSize = .zero
    /// How strongly content bends toward the rim, 0...1.
    var lensStrength: Double = 0.9
    var showsGlow: Bool = true
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()
    @State private var kickDate: Date?
    @State private var kickAmount = 0.06
    @State private var kickAngle = 0.0
    @State private var pull: CGSize = .zero

    private var activePull: CGSize {
        CGSize(width: pull.width + externalPull.width, height: pull.height + externalPull.height)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            let kick = kickDate.map { (since: timeline.date.timeIntervalSince($0), amount: kickAmount, angle: kickAngle) }
            let idle = reduceMotion ? .still : BubbleWobble.at(t, energy: energy, kick: kick)
            bubble(idle.pulled(by: activePull, diameter: diameter))
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .simultaneousGesture(pullGesture, including: pullable ? .all : .none)
        .onChange(of: kick) { _, _ in poke(amount: 0.05, angle: Double.random(in: 0...(2 * .pi))) }
        .onChange(of: externalPull == .zero) { _, released in
            // A parent's drag ended: spring back with a jiggle.
            if released { poke(amount: lastExternalAmount, angle: lastExternalAngle) }
        }
        .onChange(of: externalPull) { _, p in
            if p != .zero {
                lastExternalAmount = BubbleWobble.pullAmount(p, diameter: diameter)
                lastExternalAngle = atan2(Double(p.height), Double(p.width))
            }
        }
    }

    @State private var lastExternalAmount = 0.0
    @State private var lastExternalAngle = 0.0

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { pull = reduceMotion ? .zero : $0.translation }
            .onEnded { _ in
                let amount = BubbleWobble.pullAmount(pull, diameter: diameter)
                let angle = atan2(Double(pull.height), Double(pull.width))
                pull = .zero
                poke(amount: amount, angle: angle)
            }
    }

    private func poke(amount: Double, angle: Double) {
        guard !reduceMotion else { return }
        kickAmount = amount
        kickAngle = angle
        kickDate = Date()
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
                dropletShadow
                if colorScheme == .dark {
                    backdrop(shape)
                        .offset(x: w.drift.width * diameter, y: w.drift.height * diameter)
                }
            }
            // Before iOS 26 there's no real glass, so light mode draws a body.
            if !Self.hasLiquidGlass && colorScheme != .dark { lightBody(shape) }

            content()
                .frame(width: diameter, height: diameter)
                .distortionEffect(
                    ShaderLibrary.bubbleLens(
                        .float2(Float(center.x), Float(center.y)),
                        .float2(Float(radii.width), Float(radii.height)),
                        .float(Float(lensAngle)),
                        // Real Liquid Glass refracts on its own; the drawn lens is the fallback.
                        .float(Float(!Self.hasLiquidGlass && colorScheme == .dark ? lensStrength : 0))
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
                    colors: [Color.white.opacity(0.085), Color.white.opacity(0.03), .clear],
                    center: .center, startRadius: diameter * 0.48, endRadius: diameter * 1.1))
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
    private var dropletShadow: some View {
        // Like a droplet's shadow on the surface below: a soft round shadow that
        // stays circular while the drop above wobbles, sitting slightly low.
        ZStack {
            Circle()
                .fill(.black.opacity(colorScheme == .dark ? 0.45 : 0.13))
                .frame(width: diameter * 0.96, height: diameter * 0.96)
                .blur(radius: diameter * 0.08)
                .offset(y: diameter * 0.06)
            // A tighter contact shadow right under the drop.
            Circle()
                .fill(.black.opacity(colorScheme == .dark ? 0.35 : 0.08))
                .frame(width: diameter * 0.8, height: diameter * 0.8)
                .blur(radius: diameter * 0.03)
                .offset(y: diameter * 0.04)
        }
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

    static var hasLiquidGlass: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    @ViewBuilder
    private func glass(_ shape: BubbleShape) -> some View {
        if #available(iOS 26.0, *) {
            // Real Liquid Glass in the drop's shape: it refracts the content and
            // the stage behind it and catches light along the rim by itself.
            Color.clear
                .glassEffect(.clear.interactive(), in: shape)
                .frame(width: diameter, height: diameter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            drawnGlass(shape)
        }
    }

    /// Drawn glass for systems without Liquid Glass.
    private func drawnGlass(_ shape: BubbleShape) -> some View {
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
