//
//  GenerationPacingTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class GenerationPacingTests: XCTestCase {

    func testFirstColorHasNoLeadingSleep() {
        XCTAssertFalse(GenerationPacing.sleepsBeforeColor(at: 0))
        XCTAssertTrue(GenerationPacing.sleepsBeforeColor(at: 1))
    }

    func testIntervalsAreShortened() {
        XCTAssertEqual(GenerationPacing.colorInterval, .milliseconds(380))
        XCTAssertEqual(GenerationPacing.namingGrace, .milliseconds(600))
    }

    func testRevealStepsWithAnchorShown() {
        let steps = OnboardingPaletteMaker.revealSteps(total: 4, shown: 1)
        XCTAssertEqual(steps.map(\.count), [2, 3, 4])
        XCTAssertTrue(steps.allSatisfy(\.waitsFirst))
    }

    func testRevealStepsFromPhotoShowFirstImmediately() {
        let steps = OnboardingPaletteMaker.revealSteps(total: 4, shown: 0)
        XCTAssertEqual(steps.map(\.count), [1, 2, 3, 4])
        XCTAssertEqual(steps.map(\.waitsFirst), [false, true, true, true])
    }

    func testRevealStepsEmptyWhenAllShown() {
        XCTAssertTrue(OnboardingPaletteMaker.revealSteps(total: 1, shown: 1).isEmpty)
    }

    func testNamingRaceReturnsFastResult() async {
        let task = Task { 42 }
        let value = await NamingRace.firstResult(of: task, within: .seconds(2))
        XCTAssertEqual(value, 42)
    }

    func testNamingRaceTimesOutOnSlowTask() async {
        let task = Task { () -> Int in
            try? await Task.sleep(for: .seconds(3))
            return 1
        }
        let start = ContinuousClock.now
        let value = await NamingRace.firstResult(of: task, within: .milliseconds(100))
        task.cancel()
        XCTAssertNil(value)
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(1))
    }
}
