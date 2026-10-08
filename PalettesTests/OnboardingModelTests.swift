//
//  OnboardingModelTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class OnboardingModelTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "OnboardingModelTests")!
        defaults.removePersistentDomain(forName: "OnboardingModelTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "OnboardingModelTests")
        defaults = nil
        super.tearDown()
    }

    // MARK: - Progression

    func testStartsAtPull() {
        XCTAssertEqual(OnboardingModel(defaults: defaults).step, .pull)
    }

    func testAdvanceWalksStepsInOrder() {
        let model = OnboardingModel(defaults: defaults)
        var visited = [model.step]
        while !model.isFinished {
            model.advance()
            if !model.isFinished { visited.append(model.step) }
        }
        XCTAssertEqual(visited, [.pull, .orb, .camera, .adjust, .generate, .detail, .extras])
    }

    func testAdvancePastLastStepFinishes() {
        let model = OnboardingModel(defaults: defaults)
        for _ in OnboardingStep.allCases.dropLast() { model.advance() }
        XCTAssertEqual(model.step, .extras)
        XCTAssertFalse(model.isFinished)
        model.advance()
        XCTAssertTrue(model.isFinished)
    }

    func testAdvanceAfterFinishIsNoOp() {
        let model = OnboardingModel(defaults: defaults)
        model.skip()
        model.advance()
        XCTAssertTrue(model.isFinished)
        XCTAssertEqual(model.step, .pull)
    }

    // MARK: - Skip and completion flag

    func testSkipEndsFlowAndSetsFlag() {
        let model = OnboardingModel(defaults: defaults)
        model.advance()
        model.skip()
        XCTAssertTrue(model.isFinished)
        XCTAssertTrue(defaults.bool(forKey: OnboardingModel.completionKey))
    }

    func testFlagNotSetUntilFinished() {
        let model = OnboardingModel(defaults: defaults)
        model.advance()
        XCTAssertFalse(defaults.bool(forKey: OnboardingModel.completionKey))
    }

    func testFinishingLastStepSetsFlag() {
        let model = OnboardingModel(defaults: defaults)
        for _ in 0...OnboardingStep.allCases.count { model.advance() }
        XCTAssertTrue(model.isFinished)
        XCTAssertTrue(defaults.bool(forKey: OnboardingModel.completionKey))
    }

    // MARK: - Camera fallback

    func testPhotoFallbackLogic() {
        let model = OnboardingModel(defaults: defaults)
        model.cameraAccess = .notDetermined
        XCTAssertFalse(model.usesPhotoFallback)
        model.cameraAccess = .authorized
        XCTAssertFalse(model.usesPhotoFallback)
        model.cameraAccess = .denied
        XCTAssertTrue(model.usesPhotoFallback)
        model.cameraAccess = .restricted
        XCTAssertTrue(model.usesPhotoFallback)
        model.cameraAccess = .unavailable
        XCTAssertTrue(model.usesPhotoFallback)
    }

    // MARK: - Pull gesture

    func testRubberBandIsZeroAtZeroAndMonotonicAndBounded() {
        XCTAssertEqual(OnboardingPull.rubberBand(0), 0)
        XCTAssertEqual(OnboardingPull.rubberBand(-40), 0)
        var last = 0.0
        for d in stride(from: 10.0, through: 2000.0, by: 10.0) {
            let v = OnboardingPull.rubberBand(d)
            XCTAssertGreaterThan(v, last)
            XCTAssertLessThan(v, OnboardingPull.maxStretch)
            last = v
        }
    }

    func testCommitThreshold() {
        XCTAssertFalse(OnboardingPull.shouldCommit(translation: OnboardingPull.commitThreshold - 1))
        XCTAssertTrue(OnboardingPull.shouldCommit(translation: OnboardingPull.commitThreshold))
    }
}
