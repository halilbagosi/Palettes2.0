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
}
