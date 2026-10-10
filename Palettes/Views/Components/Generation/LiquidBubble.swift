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

// MARK: - Shape state

/// The drop's shape at one moment: a circle deformed by an oval (mode 2), a
/// one-sided bulge toward a pulling finger (mode 1), a slight three-lobed
/// wave (mode 3), and a shift of its center.
struct BubbleWobble: Equatable {
    var oval: Double = 0
    var ovalAngle: Double = 0
    var bulge: Double = 0
    var bulgeAngle: Double = 0
    var lobe: Double = 0
    var lobeAngle: Double = 0
    /// Center shift as a fraction of the diameter.
    var drift: CGSize = .zero

    static let still = BubbleWobble()
}

// MARK: - Physics

/// A soft-body model of the drop. Each deformation mode is a damped spring
/// integrated every frame, so the drop carries momentum: let go of a pull and
/// it springs back past round into a squash the other way, wobbling to rest
/// like a drop of water. While held, the springs are stiff and critically
/// damped so the shape tracks the finger with no lag or bounce.
///
/// The oval is kept as a tensor (a, b) = amount·(cos 2φ, sin 2φ): passing
/// through zero flips it to the perpendicular axis, which is exactly how a
/// stretched jelly overshoots into a squash.
final class DropPhysics {
    private struct Spring2 {
        var x = 0.0, y = 0.0, vx = 0.0, vy = 0.0
        mutating func step(toward tx: Double, _ ty: Double, response: Double, damping: Double, dt: Double) {
            let k = pow(2 * .pi / response, 2)
            let c = 4 * .pi * damping / response
            vx += (-k * (x - tx) - c * vx) * dt
            vy += (-k * (y - ty) - c * vy) * dt
            x += vx * dt
            y += vy * dt
        }
    }

    private var oval = Spring2()
    private var bulge = Spring2()
    private var center = Spring2()
    private var last: Date?

    /// Gives the drop a nudge (e.g. a color landing): oval velocity along `angle`.
    func impulse(_ strength: Double, angle: Double) {
        oval.vx += strength * cos(2 * angle)
        oval.vy += strength * sin(2 * angle)
    }

    /// Advances the simulation to `now` and returns the shape.
    /// - Parameters:
    ///   - pull: the finger's offset from where it grabbed, in points (zero when not held).
    ///   - held: whether a finger is on the drop.
    func step(to now: Date, pull: CGSize, held: Bool, diameter: CGFloat,
              idleTime t: Double, energy: Double) -> BubbleWobble {
        let dt = min(1.0 / 30, max(0, last.map { now.timeIntervalSince($0) } ?? 0))
        last = now

        // Targets from the finger, rubber-banded so the drop can't tear.
        let len = Double(hypot(pull.width, pull.height))
        // The orb can be zero-sized while tucked into the island; never divide by it.
        let d = max(Double(diameter), 1)
        let phi = atan2(Double(pull.height), Double(pull.width))
        let amount = 0.42 * (1 - exp(-len / (d * 0.9)))
        let shift = 0.22 * (1 - exp(-len / (d * 1.1)))

        // Held: track the finger tightly. Released: a bouncy water-drop spring.
        let (resp, damp) = held ? (0.11, 1.0) : (0.42, 0.26)
        let sub = 4
        for _ in 0..<sub {
            let h = dt / Double(sub)
            oval.step(toward: amount * cos(2 * phi), amount * sin(2 * phi), response: resp, damping: damp, dt: h)
            bulge.step(toward: amount * 0.2 * cos(phi), amount * 0.2 * sin(phi), response: resp, damping: held ? 1 : 0.4, dt: h)
            center.step(toward: shift * cos(phi), shift * sin(phi), response: held ? 0.14 : 0.36, damping: held ? 1 : 0.55, dt: h)
        }

        // Idle breathing on top: barely there, so it looks alive but never pulled.
        let swell = 0.5 + 0.5 * sin(t * 0.47 + 1.3) * sin(t * 0.29)
        // Subtle but always there, a touch livelier when busy.
        let liveliness = 0.6 + 0.4 * energy
        let idleOval = liveliness * (0.012 + 0.014 * swell) * sin(t * 1.3)
        let idleAngle = t * 0.45 + 0.9 * sin(t * 0.31)
        let a = oval.x + idleOval * cos(2 * idleAngle)
        let b = oval.y + idleOval * sin(2 * idleAngle)

        // A non-finite value would stick in the springs forever; reset instead.
        if ![oval.x, oval.y, oval.vx, oval.vy, bulge.x, bulge.y, center.x, center.y].allSatisfy(\.isFinite) {
            oval = Spring2(); bulge = Spring2(); center = Spring2()
            return .still
        }

        return BubbleWobble(
            oval: hypot(a, b),
            ovalAngle: atan2(b, a) / 2,
            bulge: hypot(bulge.x, bulge.y),
            bulgeAngle: atan2(bulge.y, bulge.x),
            lobe: liveliness * 0.005 * sin(t * 1.9 + 0.6) + 0.15 * hypot(oval.vx, oval.vy) * 0.02,
            lobeAngle: -t * 0.4,
            drift: CGSize(width: center.x + liveliness * 0.004 * sin(t * 0.7 + 0.4),
                          height: center.y + liveliness * 0.005 * sin(t * 0.55))
        )
    }
}

/// The drop outline for a shape state, fitted to the rect's inscribed circle.
struct BubbleShape: Shape {
    var wobble: BubbleWobble

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX + wobble.drift.width * r * 2,
                        y: rect.midY + wobble.drift.height * r * 2)
        let n = 96
        var points: [CGPoint] = []
        points.reserveCapacity(n)
        // A true ellipse that keeps its area (a·b = 1), so a stretch only ever
        // elongates the drop and never pinches its sides like it's splitting.
        let a = 1 + wobble.oval
        let b = 1 / a
        for i in 0..<n {
            let th = Double(i) / Double(n) * 2 * .pi
            let rel = th - wobble.ovalAngle
            let ellipse = (a * b) / sqrt(pow(b * cos(rel), 2) + pow(a * sin(rel), 2))
            let k = ellipse
                + wobble.bulge * cos(th - wobble.bulgeAngle)
                + wobble.lobe * cos(3 * (th - wobble.lobeAngle))
            points.append(CGPoint(x: c.x + r * k * cos(th), y: c.y + r * k * sin(th)))
        }
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

// MARK: - Stage glow

/// A soft light on the surface under where the orb rests (dark stage only). It
/// belongs to the view, not the orb, so it stays put while the drop moves.
struct BubbleStageGlow: View {
    var diameter: CGFloat
    /// Light mode: a soft grey halo, the counterpart of the dark glow, so the
    /// clear drop reads against a white stage.
    var lightHalo = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light, lightHalo {
            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: .black.opacity(0.07), location: 0),
                            .init(color: .black.opacity(0.05), location: 0.45),
                            .init(color: .black.opacity(0.015), location: 0.75),
                            .init(color: .clear, location: 1)],
                    center: .center, startRadius: 0, endRadius: diameter * 1.25))
                .frame(width: diameter * 2.5, height: diameter * 2.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else if colorScheme == .dark {
            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: .white.opacity(0.09), location: 0),
                            .init(color: .white.opacity(0.06), location: 0.45),
                            .init(color: .white.opacity(0.02), location: 0.75),
                            .init(color: .clear, location: 1)],
                    center: .center, startRadius: 0, endRadius: diameter * 1.25))
                .frame(width: diameter * 2.5, height: diameter * 2.5)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Bubble

struct LiquidBubble<Content: View>: View {
    var diameter: CGFloat
    /// Idle liveliness: 0 still, ~0.4 resting, 1 busy.
    var energy: Double = 0.4
    /// Change this to nudge the drop (a small wobble that settles).
    var kick: Int = 0
    /// When true the user can grab the drop and pull it out of shape; it
    /// springs back with momentum on release.
    var pullable: Bool = false
    /// An external pull (e.g. a parent's own drag gesture), in points.
    var externalPull: CGSize = .zero
    /// How strongly content bends toward the rim, 0...1 (drawn-glass fallback only).
    var lensStrength: Double = 0.9
    var showsGlow: Bool = true
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()
    @State private var physics = DropPhysics()
    @State private var pull: CGSize = .zero
    @State private var holding = false

    private var activePull: CGSize {
        CGSize(width: pull.width + externalPull.width, height: pull.height + externalPull.height)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let shape = reduceMotion ? .still : physics.step(
                to: timeline.date,
                pull: activePull,
                held: holding || externalPull != .zero,
                diameter: diameter,
                idleTime: timeline.date.timeIntervalSince(start),
                energy: energy)
            bubble(shape)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .simultaneousGesture(pullGesture, including: pullable ? .all : .none)
        .onChange(of: kick) { _, _ in
            guard !reduceMotion else { return }
            physics.impulse(0.9, angle: Double.random(in: 0...(2 * .pi)))
        }
    }

    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                holding = true
                pull = reduceMotion ? .zero : value.translation
            }
            .onEnded { _ in
                holding = false
                pull = .zero
            }
    }

    private func bubble(_ w: BubbleWobble) -> some View {
        let shape = BubbleShape(wobble: w)
        let r = diameter / 2
        let center = CGPoint(x: r + w.drift.width * diameter, y: r + w.drift.height * diameter)
        // The lens follows the current oval.
        let radii = CGSize(width: r * (1 + w.oval), height: r / (1 + w.oval))
        let lensAngle = w.ovalAngle

        return ZStack {
            if showsGlow {
                dropletShadow(shape)
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

            // The shadow continues under the drop: the glass frosts what's
            // beneath it, so the part inside the outline is drawn over the glass,
            // faintly, as if seen through clear water.
            if showsGlow && colorScheme != .dark {
                dropletShadow(shape)
                    .mask(shape.frame(width: diameter, height: diameter))
                    .opacity(0.8)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// Dark stage: a soft white glow around the bubble only, so the water
    /// itself stays dark and clear.
    /// Light stage: a large soft grey shadow all around, like a drop of water
    /// resting just above white paper.
    /// Like a droplet's shadow on the surface below: a thin soft ring that
    /// follows the drop's shape as it wobbles, sitting a little lower.
    private func dropletShadow(_ shape: BubbleShape) -> some View {
        // A thin soft ring on the surface under the drop, sitting a little low and
        // following its shape. Same geometry in both modes; darker on the dark stage.
        let dark = colorScheme == .dark
        return ZStack {
            shape
                .stroke(.black.opacity(dark ? 0.4 : 0.06), lineWidth: diameter * 0.06)
                .blur(radius: diameter * 0.045)
            // Faint spread so the ring sits on the surface rather than floating.
            shape
                .stroke(.black.opacity(dark ? 0.18 : 0.025), lineWidth: diameter * 0.16)
                .blur(radius: diameter * 0.1)
        }
        .frame(width: diameter, height: diameter)
        .offset(y: diameter * 0.2)
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
