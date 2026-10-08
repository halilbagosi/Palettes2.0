//
//  OnboardingModelTests.swift
//  PalettesTests
//

import XCTest
import AVFoundation
import ImageIO
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
        let fallback: [(OnboardingCameraAccess, Bool)] = [
            (.notDetermined, false), (.authorized, false),
            (.denied, true), (.restricted, true), (.unavailable, true),
        ]
        for (access, expected) in fallback {
            model.cameraAccess = access
            XCTAssertEqual(model.cameraUIState == .photoFallback, expected)
        }
    }

    func testReplayResetsAllOnboardingFlags() {
        let defaults = UserDefaults(suiteName: "OnboardingModelTests.\(UUID().uuidString)")!
        for key in [OnboardingKeys.didComplete, OnboardingKeys.didShowCoachMark, OnboardingKeys.didShowExtras] {
            defaults.set(true, forKey: key)
        }
        OnboardingKeys.resetForReplay(defaults)
        for key in [OnboardingKeys.didComplete, OnboardingKeys.didShowCoachMark, OnboardingKeys.didShowExtras] {
            XCTAssertFalse(defaults.bool(forKey: key), key)
        }
    }

    // MARK: - Camera permission mapping

    func testAuthorizationStatusMapping() {
        let cases: [(AVAuthorizationStatus, OnboardingCameraAccess)] = [
            (.notDetermined, .notDetermined), (.authorized, .authorized),
            (.denied, .denied), (.restricted, .restricted),
        ]
        for (status, expected) in cases {
            XCTAssertEqual(OnboardingCameraAccess(status: status, hasDevice: true), expected)
        }
    }

    func testNoDeviceWinsOverAnyStatus() {
        for status in [AVAuthorizationStatus.notDetermined, .authorized, .denied, .restricted] {
            XCTAssertEqual(OnboardingCameraAccess(status: status, hasDevice: false), .unavailable)
        }
    }

    func testCameraUIStateMapping() {
        let model = makeModel()
        let expected: [(OnboardingCameraAccess, OnboardingCameraUIState)] = [
            (.notDetermined, .needsPermission), (.authorized, .live),
            (.denied, .photoFallback), (.restricted, .photoFallback), (.unavailable, .photoFallback),
        ]
        for (access, state) in expected {
            model.cameraAccess = access
            XCTAssertEqual(model.cameraUIState, state)
        }
    }

    func testSampleImageIsRenderable() {
        let image = OnboardingSampleImage.make(size: CGSize(width: 40, height: 40))
        XCTAssertEqual(image.size, CGSize(width: 40, height: 40))
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

final class PhotoCaptureCoordinatorTests: XCTestCase {
    private final class Box: @unchecked Sendable {
        var results: [Data?] = []
    }

    private func makeCoordinator(_ box: Box) -> PhotoCaptureCoordinator {
        PhotoCaptureCoordinator { box.results.append($0) }
    }

    func testResumesOnceWithProcessedData() {
        let box = Box()
        let coordinator = makeCoordinator(box)
        let data = Data([1, 2, 3])
        coordinator.didProcess(data: data, error: nil)
        XCTAssertTrue(box.results.isEmpty, "must wait for didFinishCapture")
        coordinator.didFinishCapture(error: nil)
        coordinator.didFinishCapture(error: nil)
        coordinator.cancel()
        XCTAssertEqual(box.results, [data])
    }

    func testCancelResumesNilAndIgnoresLaterCallbacks() {
        let box = Box()
        let coordinator = makeCoordinator(box)
        coordinator.cancel()
        coordinator.didProcess(data: Data([9]), error: nil)
        coordinator.didFinishCapture(error: nil)
        XCTAssertEqual(box.results.count, 1)
        XCTAssertNil(box.results[0])
    }

    func testErrorResumesNil() {
        let box = Box()
        let coordinator = makeCoordinator(box)
        coordinator.didProcess(data: Data([1]), error: NSError(domain: "x", code: 1))
        coordinator.didFinishCapture(error: nil)
        XCTAssertEqual(box.results.count, 1)
        XCTAssertNil(box.results[0])
    }

    func testFinishWithoutPhotoResumesNil() {
        let box = Box()
        let coordinator = makeCoordinator(box)
        coordinator.didFinishCapture(error: nil)
        XCTAssertEqual(box.results.count, 1)
        XCTAssertNil(box.results[0])
    }
}

final class OnboardingImageLoaderTests: XCTestCase {
    func testDownscalesLongSideAndKeepsAspect() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000), format: format).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let data = try XCTUnwrap(source.pngData())
        let image = try XCTUnwrap(OnboardingImageLoader.downscaled(from: data))
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertEqual(max(cg.width, cg.height), OnboardingImageLoader.maxPixelSize)
        XCTAssertEqual(Double(cg.width) / Double(cg.height), 1.5, accuracy: 0.01)
    }

    func testAppliesEXIFOrientation() throws {
        // A landscape JPEG tagged "rotated 90 degrees" must come out portrait.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let source = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200), format: format).image { ctx in
            UIColor.blue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        }
        let cgImage = try XCTUnwrap(source.cgImage)
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let image = try XCTUnwrap(OnboardingImageLoader.downscaled(from: output as Data))
        let cg = try XCTUnwrap(image.cgImage)
        XCTAssertGreaterThan(cg.height, cg.width)
    }

    func testGarbageDataReturnsNil() {
        XCTAssertNil(OnboardingImageLoader.downscaled(from: Data([0, 1, 2])))
    }
}
