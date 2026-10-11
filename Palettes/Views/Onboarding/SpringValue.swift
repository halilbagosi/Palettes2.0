//
//  SpringValue.swift
//  Palettes
//
//  A tiny spring integrator whose on-screen value is always known. SwiftUI
//  cannot read the current value of an in-flight `withAnimation`, so anything
//  that must be interrupted mid-flight, or hand its velocity to the next
//  motion, runs through this instead. Semi-implicit Euler, stepped at display
//  rate only while it is not settled.
//

import SwiftUI
import Combine
import QuartzCore

/// Apple-style spring parameters, converted to physical constants.
struct SpringParameters: Equatable {
    var response: Double
    var dampingFraction: Double

    /// k = (2π / response)²
    var stiffness: Double { pow(2 * .pi / response, 2) }
    /// c = 4π·ζ / response
    var damping: Double { 4 * .pi * dampingFraction / response }
}

@MainActor
final class SpringValue: ObservableObject {
    /// Settled when closer to the target than this and slower than `settleVelocity`.
    nonisolated static let settleDistance = 0.001
    nonisolated static let settleVelocity = 0.01
    /// Largest integration step. Display-rate frames are split below this so the
    /// result does not depend on the frame rate.
    nonisolated static let maxStep = 1.0 / 240.0

    @Published private(set) var value: Double
    private(set) var velocity: Double = 0
    private(set) var target: Double
    private(set) var parameters = SpringParameters(response: 0.5, dampingFraction: 1)

    /// Called after every change of `value`, on the same frame.
    var onUpdate: (() -> Void)?
    /// Called once when an animation comes to rest at its target.
    var onSettle: (() -> Void)?

    private var isAnimating = false
    private var link: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    private var lastTrackTime: CFTimeInterval?

    /// False in tests, which step the simulation by hand.
    private let usesDisplayLink: Bool

    init(_ value: Double = 0, usesDisplayLink: Bool = true) {
        self.value = value
        self.target = value
        self.usesDisplayLink = usesDisplayLink
    }

    var isSettled: Bool {
        abs(value - target) < Self.settleDistance && abs(velocity) < Self.settleVelocity
    }

    // MARK: Driving

    /// Springs to `target`. `initialVelocity` replaces the current velocity
    /// when given (the gesture's release velocity); otherwise the motion
    /// continues from wherever it is, which is what makes it interruptible.
    func animate(
        to target: Double,
        response: Double,
        dampingFraction: Double,
        initialVelocity: Double? = nil
    ) {
        parameters = SpringParameters(response: response, dampingFraction: dampingFraction)
        self.target = target
        if let initialVelocity { velocity = initialVelocity }
        lastTrackTime = nil
        if isSettled {
            finish()
        } else {
            startLink()
        }
    }

    /// Sets the value directly (a finger is driving it) and keeps a smoothed
    /// velocity estimate for the hand-off on release.
    /// `time` should be the input event's timestamp.
    func track(_ newValue: Double, at time: CFTimeInterval) {
        stopLink()
        if let last = lastTrackTime {
            let dt = max(time - last, 1.0 / 240.0)
            let instant = (newValue - value) / dt
            velocity = velocity * 0.35 + instant * 0.65
        } else {
            velocity = 0
        }
        lastTrackTime = time
        value = newValue
        target = newValue
        onUpdate?()
    }

    /// Velocity to hand to the next animation: zero when the finger paused
    /// before letting go.
    func releaseVelocity(at time: CFTimeInterval) -> Double {
        guard let last = lastTrackTime, time - last < 0.1 else { return 0 }
        return velocity
    }

    /// Jumps to `newValue` and stops, with no velocity.
    func jump(to newValue: Double) {
        stopLink()
        value = newValue
        target = newValue
        velocity = 0
        lastTrackTime = nil
        onUpdate?()
    }

    /// Freezes in place (a new touch grabbed it), keeping the velocity.
    func freeze() {
        stopLink()
        target = value
        lastTrackTime = nil
    }

    /// Advances the simulation by `dt` seconds. Public so tests can step it
    /// deterministically; the display link calls it with real frame times.
    func advance(by dt: Double) {
        guard dt > 0, isAnimating else { return }
        let k = parameters.stiffness
        let c = parameters.damping
        var remaining = dt
        while remaining > 0 {
            let h = min(remaining, Self.maxStep)
            // Semi-implicit Euler: velocity first, then position with the new velocity.
            velocity += (-k * (value - target) - c * velocity) * h
            value += velocity * h
            remaining -= h
        }
        if isSettled {
            value = target
            velocity = 0
        }
        onUpdate?()
        if isSettled { finish() }
    }

    // MARK: Display link

    private func startLink() {
        isAnimating = true
        guard usesDisplayLink, link == nil else { return }
        let proxy = DisplayLinkProxy(owner: self)
        let newLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        lastFrame = CACurrentMediaTime()
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    private func stopLink() {
        link?.invalidate()
        link = nil
        isAnimating = false
    }

    fileprivate func frame(at time: CFTimeInterval) {
        let dt = min(time - lastFrame, 1.0 / 20.0) * OnboardingDebug.timeScale
        lastFrame = time
        advance(by: dt)
    }

    private func finish() {
        let wasAnimating = isAnimating
        stopLink()
        if wasAnimating || value != target {
            value = target
            velocity = 0
        }
        onSettle?()
    }
}

/// Keeps the display link from retaining the spring.
private final class DisplayLinkProxy: NSObject {
    weak var owner: SpringValue?

    init(owner: SpringValue) { self.owner = owner }

    @objc func tick(_ link: CADisplayLink) {
        MainActor.assumeIsolated {
            owner?.frame(at: link.timestamp)
        }
    }
}

// MARK: - Easing helpers

enum Easing {
    static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }

    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// Hermite smoothstep between `edge0` and `edge1`.
    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3 - 2 * t)
    }

    /// Apple's deceleration projection: where a release at `velocity`
    /// (units per second) would come to rest.
    static func project(position: Double, velocity: Double, decelerationRate: Double = 0.998) -> Double {
        position + (velocity / 1000) * decelerationRate / (1 - decelerationRate)
    }
}
