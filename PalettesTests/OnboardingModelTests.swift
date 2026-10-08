//
//  OnboardingModelTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class OnboardingModelTests: XCTestCase {

    private var finishes: [OnboardingFinishReason] = []

    private func makeModel() -> OnboardingModel {
        finishes = []
        return OnboardingModel { [unowned self] in finishes.append($0) }
    }

    // MARK: - Progression

    func testStartsAtPull() {
        XCTAssertEqual(makeModel().step, .pull)
    }

    func testInCoverStepsEndAtGenerate() {
        XCTAssertEqual(OnboardingStep.allCases, [.pull, .orb, .camera, .adjust, .generate])
    }

    func testAdvanceWalksStepsInOrder() {
        let model = makeModel()
        var visited = [model.step]
        for _ in 0..<10 {
            model.advance()
            if visited.last != model.step { visited.append(model.step) }
        }
        XCTAssertEqual(visited, OnboardingStep.allCases)
    }

    func testAdvancePastLastStepDoesNotFinish() {
        let model = makeModel()
        for _ in 0..<10 { model.advance() }
        XCTAssertEqual(model.step, .generate)
        XCTAssertFalse(model.isFinished)
        XCTAssertTrue(finishes.isEmpty)
    }

    func testAdvanceAfterFinishIsNoOp() {
        let model = makeModel()
        model.skip()
        model.advance()
        XCTAssertEqual(model.step, .pull)
    }

    // MARK: - Finish reasons

    func testSkipFromPullReportsSkipped() {
        let model = makeModel()
        model.skip()
        XCTAssertTrue(model.isFinished)
        XCTAssertEqual(finishes, [.skipped])
    }

    func testSkipMidFlowReportsSkipped() {
        let model = makeModel()
        model.advance()
        model.advance()
        model.skip()
        XCTAssertEqual(finishes, [.skipped])
    }

    func testCompletedCarriesPaletteID() {
        let model = makeModel()
        let id = UUID()
        model.finish(.completed(paletteID: id))
        XCTAssertEqual(finishes, [.completed(paletteID: id)])
    }

    func testFinishIsIdempotent() {
        let model = makeModel()
        model.skip()
        model.skip()
        model.finish(.completed(paletteID: UUID()))
        XCTAssertEqual(finishes, [.skipped])
    }

    func testNothingFiresBeforeFinish() {
        let model = makeModel()
        model.advance()
        XCTAssertTrue(finishes.isEmpty)
    }

    // MARK: - Camera fallback

    func testPhotoFallbackLogic() {
        let model = makeModel()
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

    func testFastFlickCommitsOnPredictedEnd() {
        let short = OnboardingPull.commitThreshold / 3
        XCTAssertFalse(OnboardingPull.shouldCommit(translation: short, predictedEnd: short))
        XCTAssertTrue(OnboardingPull.shouldCommit(
            translation: short, predictedEnd: OnboardingPull.commitThreshold * 2
        ))
    }
}

@MainActor
final class OnboardingReplayCoordinatorTests: XCTestCase {
    func testConsumeWithoutRequestIsFalse() {
        XCTAssertFalse(OnboardingReplayCoordinator().consume())
    }

    func testRequestIsConsumedOnce() {
        let coordinator = OnboardingReplayCoordinator()
        coordinator.request()
        XCTAssertTrue(coordinator.consume())
        XCTAssertFalse(coordinator.consume())
    }
}
