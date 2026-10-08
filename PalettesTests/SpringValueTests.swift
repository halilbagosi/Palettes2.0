import XCTest
@testable import Palettes

@MainActor
final class SpringValueTests: XCTestCase {
    private func run(_ spring: SpringValue, seconds: Double, dt: Double = 1.0 / 120.0) -> [Double] {
        var samples: [Double] = []
        var t = 0.0
        while t < seconds {
            spring.advance(by: dt)
            samples.append(spring.value)
            t += dt
        }
        return samples
    }

    func testParametersConvertAppleResponseAndDamping() {
        let p = SpringParameters(response: 0.5, dampingFraction: 0.8)
        XCTAssertEqual(p.stiffness, pow(2 * .pi / 0.5, 2), accuracy: 1e-9)
        XCTAssertEqual(p.damping, 4 * .pi * 0.8 / 0.5, accuracy: 1e-9)
    }

    func testConvergesToTargetAndSettles() {
        let spring = SpringValue(0, usesDisplayLink: false)
        var settled = 0
        spring.onSettle = { settled += 1 }
        spring.animate(to: 100, response: 0.5, dampingFraction: 0.8)
        _ = run(spring, seconds: 3)
        XCTAssertEqual(spring.value, 100)
        XCTAssertEqual(spring.velocity, 0)
        XCTAssertTrue(spring.isSettled)
        XCTAssertEqual(settled, 1)
    }

    func testUnderdampedOvershoots() {
        let spring = SpringValue(0, usesDisplayLink: false)
        spring.animate(to: 1, response: 0.5, dampingFraction: 0.5)
        let peak = run(spring, seconds: 2).max() ?? 0
        XCTAssertGreaterThan(peak, 1.05)
    }

    func testCriticallyDampedDoesNotOvershoot() {
        let spring = SpringValue(0, usesDisplayLink: false)
        spring.animate(to: 1, response: 0.5, dampingFraction: 1)
        let peak = run(spring, seconds: 2).max() ?? 0
        XCTAssertLessThanOrEqual(peak, 1.0001)
    }

    func testResultDoesNotDependOnFrameRate() {
        let a = SpringValue(0, usesDisplayLink: false)
        let b = SpringValue(0, usesDisplayLink: false)
        a.animate(to: 1, response: 0.4, dampingFraction: 0.7)
        b.animate(to: 1, response: 0.4, dampingFraction: 0.7)
        _ = run(a, seconds: 0.3, dt: 1.0 / 60.0)
        _ = run(b, seconds: 0.3, dt: 1.0 / 120.0)
        XCTAssertEqual(a.value, b.value, accuracy: 0.01)
    }

    func testInitialVelocityIsHandedOff() {
        let still = SpringValue(0, usesDisplayLink: false)
        let flung = SpringValue(0, usesDisplayLink: false)
        still.animate(to: 1, response: 0.5, dampingFraction: 1)
        flung.animate(to: 1, response: 0.5, dampingFraction: 1, initialVelocity: 6)
        still.advance(by: 0.05)
        flung.advance(by: 0.05)
        XCTAssertGreaterThan(flung.value, still.value * 2)
    }

    func testRetargetingMidFlightKeepsValueAndVelocityContinuous() {
        let spring = SpringValue(0, usesDisplayLink: false)
        spring.animate(to: 100, response: 0.5, dampingFraction: 0.9)
        _ = run(spring, seconds: 0.2)
        let value = spring.value
        let velocity = spring.velocity
        XCTAssertGreaterThan(velocity, 0)
        spring.animate(to: 0, response: 0.35, dampingFraction: 1)
        XCTAssertEqual(spring.value, value)
        XCTAssertEqual(spring.velocity, velocity)
        // Still travelling toward the old target for a moment (inertia), then returns.
        spring.advance(by: 1.0 / 120.0)
        XCTAssertGreaterThan(spring.value, value - 0.5)
        _ = run(spring, seconds: 3)
        XCTAssertEqual(spring.value, 0)
    }

    func testTrackSetsValueDirectlyAndEstimatesVelocity() {
        let spring = SpringValue(0, usesDisplayLink: false)
        spring.track(0, at: 10.00)
        spring.track(10, at: 10.01)
        spring.track(20, at: 10.02)
        XCTAssertEqual(spring.value, 20)
        XCTAssertGreaterThan(spring.velocity, 700)
        XCTAssertLessThan(spring.velocity, 1100)
        XCTAssertEqual(spring.releaseVelocity(at: 10.03), spring.velocity)
        // A finger that rested before lifting hands off no velocity.
        XCTAssertEqual(spring.releaseVelocity(at: 10.5), 0)
    }

    func testJumpStopsAnimationAndVelocity() {
        let spring = SpringValue(0, usesDisplayLink: false)
        spring.animate(to: 50, response: 0.5, dampingFraction: 0.8, initialVelocity: 100)
        spring.advance(by: 0.05)
        spring.jump(to: 7)
        XCTAssertEqual(spring.value, 7)
        XCTAssertEqual(spring.velocity, 0)
        XCTAssertTrue(spring.isSettled)
    }

    func testProjectionMatchesAppleDeceleration() {
        XCTAssertEqual(Easing.project(position: 10, velocity: 0), 10)
        XCTAssertEqual(Easing.project(position: 0, velocity: 1000), 499, accuracy: 0.001)
    }

    func testSmoothstep() {
        XCTAssertEqual(Easing.smoothstep(0.2, 0.8, 0.1), 0)
        XCTAssertEqual(Easing.smoothstep(0.2, 0.8, 0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Easing.smoothstep(0.2, 0.8, 0.9), 1)
    }
}
