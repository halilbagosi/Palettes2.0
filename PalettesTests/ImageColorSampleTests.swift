//
//  ImageColorSampleTests.swift
//  PalettesTests
//

import XCTest
import UIKit
@testable import Palettes

final class ImageColorSampleTests: XCTestCase {

    /// Draws a `size`×`size` image whose left half is `left` and right half is `right`.
    private func splitImage(left: UIColor, right: UIColor, size: CGFloat = 40) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            left.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size / 2, height: size))
            right.setFill()
            ctx.fill(CGRect(x: size / 2, y: 0, width: size / 2, height: size))
        }
    }

    private func solidImage(_ color: UIColor, size: CGFloat = 40) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    func testSamplesSolidColorAnywhere() {
        let img = solidImage(.red)
        let c = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(c.r, 255, accuracy: 4)
        XCTAssertEqual(c.g, 0, accuracy: 4)
        XCTAssertEqual(c.b, 0, accuracy: 4)
    }

    func testSamplesLeftAndRightHalvesDistinctly() {
        let img = splitImage(left: .red, right: .blue)
        let left = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.2, y: 0.5))
        let right = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.8, y: 0.5))
        XCTAssertEqual(left.r, 255, accuracy: 6)
        XCTAssertEqual(left.b, 0, accuracy: 6)
        XCTAssertEqual(right.b, 255, accuracy: 6)
        XCTAssertEqual(right.r, 0, accuracy: 6)
    }

    func testTopLeftOriginConvention() {
        // Top half green, bottom half black — verifies (0,0) is the top.
        let size: CGFloat = 40
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            UIColor.green.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size / 2))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: size / 2, width: size, height: size / 2))
        }
        let top = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.5, y: 0.1))
        XCTAssertEqual(top.g, 255, accuracy: 6)
        XCTAssertEqual(top.r, 0, accuracy: 6)
    }

    func testOutOfBoundsPointClampsWithoutCrashing() {
        let img = solidImage(.red)
        let c = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: -0.5, y: 1.9))
        XCTAssertEqual(c.r, 255, accuracy: 4)
    }

    // MARK: - PixelSampler (reused across a drag)

    func testPixelSamplerReusedForMultiplePointsMatchesOneOff() throws {
        let img = splitImage(left: .red, right: .blue)
        let sampler = try XCTUnwrap(ImageColorExtractor.PixelSampler(image: img))

        // A single rasterization answers many queries, matching the one-off API.
        let left = sampler.color(at: CGPoint(x: 0.2, y: 0.5))
        let right = sampler.color(at: CGPoint(x: 0.8, y: 0.5))
        XCTAssertEqual(left.r, 255, accuracy: 6)
        XCTAssertEqual(left.b, 0, accuracy: 6)
        XCTAssertEqual(right.b, 255, accuracy: 6)
        XCTAssertEqual(right.r, 0, accuracy: 6)

        let oneOff = ImageColorExtractor.sampleColor(from: img, at: CGPoint(x: 0.2, y: 0.5))
        XCTAssertEqual(left.r, oneOff.r, accuracy: 0.001)
        XCTAssertEqual(left.g, oneOff.g, accuracy: 0.001)
        XCTAssertEqual(left.b, oneOff.b, accuracy: 0.001)
    }

    // MARK: - extractColors (Lab-space salience ranking)

    private func colorForHex(_ hex: String) -> UIColor {
        var c = hex
        if c.hasPrefix("#") { c.removeFirst() }
        let n = UInt64(c, radix: 16) ?? 0
        return UIColor(
            red: CGFloat((n >> 16) & 0xFF) / 255.0,
            green: CGFloat((n >> 8) & 0xFF) / 255.0,
            blue: CGFloat(n & 0xFF) / 255.0,
            alpha: 1
        )
    }

    private func imageWithPatch(
        background: String,
        patch: String,
        patchRect: CGRect,
        size: CGFloat = 200
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            colorForHex(background).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            colorForHex(patch).setFill()
            ctx.fill(patchRect)
        }
    }

    private func closestDelta(_ hex: String, in colors: [ImageColorExtractor.ExtractedColor]) -> Double {
        colors.map { ColorNamer.perceptualDistance(hex1: $0.hex, hex2: hex) }.min() ?? .greatestFiniteMagnitude
    }

    func testSmallAccentSurvivesExtraction() throws {
        // Five competing regions (four muted, low-chroma; one vivid, small) so the
        // count:4 budget forces a real choice between raw pixel-share and
        // chroma-boosted salience. Shares: 30% / 30% / 25% / 10% / 5%(accent).
        // Under plain size-ranking the 10% muted region beats the 5% vivid patch;
        // under salience (share * (0.5 + min(1, chroma/100))) the vivid patch wins.
        let size: CGFloat = 200
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let img = renderer.image { ctx in
            colorForHex("#8C7868").setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 60, height: size))
            colorForHex("#688C78").setFill()
            ctx.fill(CGRect(x: 60, y: 0, width: 60, height: size))
            colorForHex("#78688C").setFill()
            ctx.fill(CGRect(x: 120, y: 0, width: 50, height: size))
            colorForHex("#808080").setFill()
            ctx.fill(CGRect(x: 170, y: 0, width: 20, height: size))
            colorForHex("#FF3B30").setFill()
            ctx.fill(CGRect(x: 190, y: 0, width: 10, height: size))
        }
        let results = try ImageColorExtractor.extractColors(from: img, count: 4)
        XCTAssertLessThan(closestDelta("#FF3B30", in: results), 12.0)
    }

    func testLabSeparationKeepsPerceptuallyDistinctPair() throws {
        // RGB-close-ish but perceptually distinct pair (blue-gray vs green-gray).
        let img = splitImage(left: colorForHex("#4A6FA5"), right: colorForHex("#4AA56F"), size: 200)
        let results = try ImageColorExtractor.extractColors(from: img, count: 4)
        XCTAssertLessThan(closestDelta("#4A6FA5", in: results), 12.0)
        XCTAssertLessThan(closestDelta("#4AA56F", in: results), 12.0)
    }

    func testSpeckleIsRejected() throws {
        // ~0.01% area speckle should not survive the share threshold.
        let img = imageWithPatch(
            background: "#777777",
            patch: "#FF00FF",
            patchRect: CGRect(x: 100, y: 100, width: 2, height: 2)
        )
        let results = try ImageColorExtractor.extractColors(from: img, count: 4)
        XCTAssertGreaterThanOrEqual(closestDelta("#FF00FF", in: results), 12.0)
    }
}
