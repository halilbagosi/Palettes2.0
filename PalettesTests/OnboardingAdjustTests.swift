//
//  OnboardingAdjustTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

@MainActor
final class OnboardingAdjustTests: XCTestCase {

    // MARK: - Tap mapping in the circular orb

    func testCenterTapOfSquareImageIsCenter() {
        let p = OnboardingSampling.normalizedPoint(
            forTap: CGPoint(x: 100, y: 100), imageSize: CGSize(width: 400, height: 400), diameter: 200)
        XCTAssertEqual(p?.x ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(p?.y ?? -1, 0.5, accuracy: 0.001)
    }

    func testLandscapeImageIsCroppedByScaledToFill() {
        // 400x200 fills a 200 square at scale 1: drawn 400x200... height fits, width overflows.
        let size = CGSize(width: 400, height: 200)
        let rect = OnboardingSampling.fillRect(imageSize: size, diameter: 200)
        XCTAssertEqual(rect.width, 400, accuracy: 0.001)
        XCTAssertEqual(rect.height, 200, accuracy: 0.001)
        XCTAssertEqual(rect.minX, -100, accuracy: 0.001)
        // The orb's left edge shows a quarter of the way into the image.
        let p = OnboardingSampling.normalizedPoint(forTap: CGPoint(x: 0, y: 100), imageSize: size, diameter: 200)
        XCTAssertEqual(p?.x ?? -1, 0.25, accuracy: 0.001)
        XCTAssertEqual(p?.y ?? -1, 0.5, accuracy: 0.001)
    }

    func testPortraitImageCropsVertically() {
        let size = CGSize(width: 200, height: 400)
        let p = OnboardingSampling.normalizedPoint(forTap: CGPoint(x: 100, y: 0), imageSize: size, diameter: 200)
        XCTAssertEqual(p?.x ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(p?.y ?? -1, 0.25, accuracy: 0.001)
    }

    func testTapOutsideCircleIsIgnored() {
        // Inside the bounding square but outside the circle.
        XCTAssertNil(OnboardingSampling.normalizedPoint(
            forTap: CGPoint(x: 5, y: 5), imageSize: CGSize(width: 100, height: 100), diameter: 200))
        XCTAssertNotNil(OnboardingSampling.normalizedPoint(
            forTap: CGPoint(x: 100, y: 2), imageSize: CGSize(width: 100, height: 100), diameter: 200))
    }

    func testOrbPointInvertsNormalizedPoint() {
        let size = CGSize(width: 300, height: 200)
        let tap = CGPoint(x: 120, y: 80)
        let n = OnboardingSampling.normalizedPoint(forTap: tap, imageSize: size, diameter: 200)!
        let back = OnboardingSampling.orbPoint(forNormalized: n, imageSize: size, diameter: 200)
        XCTAssertEqual(back.x, tap.x, accuracy: 0.001)
        XCTAssertEqual(back.y, tap.y, accuracy: 0.001)
    }

    // MARK: - Adjustments

    func testNeutralSlidersLeaveColorUnchanged() {
        let model = OnboardingModel()
        model.scannedRGB = (r: 200, g: 100, b: 50)
        let rgb = model.adjustedRGB!
        XCTAssertEqual(rgb.r, 200, accuracy: 1)
        XCTAssertEqual(rgb.g, 100, accuracy: 1)
        XCTAssertEqual(rgb.b, 50, accuracy: 1)
        XCTAssertEqual(model.selectedHex, "#C86432")
    }

    func testBrightnessAndSaturationApplyThroughColorAdjustment() {
        let model = OnboardingModel()
        model.scannedRGB = (r: 200, g: 100, b: 50)
        model.brightness = 0.2
        model.saturation = 0.8
        let expected = ColorAdjustment.apply(
            baseR: 200, baseG: 100, baseB: 50, temperature: 0.5, saturation: 0.8, brightness: 0.2)
        let rgb = model.adjustedRGB!
        XCTAssertEqual(rgb.r, expected.r, accuracy: 0.001)
        XCTAssertEqual(rgb.g, expected.g, accuracy: 0.001)
        XCTAssertEqual(rgb.b, expected.b, accuracy: 0.001)
        XCTAssertLessThan(rgb.r, 200) // darker
    }

    func testNoSelectionBeforeScan() {
        let model = OnboardingModel()
        XCTAssertNil(model.adjustedRGB)
        XCTAssertNil(model.selectedHex)
    }

    // MARK: - Palette and finish

    func testDeterministicPaletteKeepsAnchorAndAlignment() throws {
        let palette = try OnboardingPaletteMaker.deterministicPalette(anchorHex: "#C86432", seed: 7)
        XCTAssertEqual(palette.paletteColors.count, 4)
        XCTAssertEqual(palette.hexCodes.first, "#C86432")
        XCTAssertEqual(palette.colors.count, palette.hexCodes.count)
        XCTAssertEqual(palette.colorNames.count, palette.hexCodes.count)
        XCTAssertEqual(palette.colorRoles.count, palette.hexCodes.count)
        XCTAssertFalse(palette.name.isEmpty)
        XCTAssertFalse(palette.isGenerated)
    }

    func testSaveCreatesPaletteThroughAppDataAndFinishesWithItsID() throws {
        var reasons: [OnboardingFinishReason] = []
        let model = OnboardingModel { reasons.append($0) }
        let appData = AppData(inMemory: true)
        let palette = try OnboardingPaletteMaker.deterministicPalette(anchorHex: "#3A6EA5", seed: 3)

        let id = OnboardingPaletteSaver.save(palette, appData: appData, model: model)

        XCTAssertEqual(appData.palettes.count, 1)
        XCTAssertEqual(appData.palettes.first?.id, id)
        XCTAssertEqual(appData.palettes.first?.hexCodes, palette.hexCodes)
        XCTAssertEqual(appData.palettes.first?.colorRoles, palette.colorRoles)
        XCTAssertEqual(reasons, [.completed(paletteID: id)])
        XCTAssertTrue(model.isFinished)
    }
}
