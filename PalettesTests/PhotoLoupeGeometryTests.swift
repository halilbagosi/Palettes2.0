//
//  PhotoLoupeGeometryTests.swift
//  PalettesTests
//

import XCTest
import CoreGraphics
@testable import Palettes

final class PhotoLoupeGeometryTests: XCTestCase {

    func testCenterMapsToCenterForSquareInSquare() {
        let p = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 100),
            viewSize: CGSize(width: 200, height: 200),
            imageSize: CGSize(width: 500, height: 500)
        )
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }

    func testLandscapeImageInSquareViewHasVerticalBars() {
        // 2:1 image in 200×200 view: displayed 200 wide, 100 tall, 50pt bars top/bottom.
        let view = CGSize(width: 200, height: 200)
        let image = CGSize(width: 400, height: 200)

        // Center of the displayed image (y = 100) → (0.5, 0.5).
        let center = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(center.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(center.y, 0.5, accuracy: 0.001)

        // Top edge of displayed image is at y = 50 → normalized y = 0.
        let topEdge = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 50), viewSize: view, imageSize: image)
        XCTAssertEqual(topEdge.y, 0.0, accuracy: 0.001)

        // A touch in the top bar (y = 10) clamps to 0.
        let inBar = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 100, y: 10), viewSize: view, imageSize: image)
        XCTAssertEqual(inBar.y, 0.0, accuracy: 0.001)
    }

    func testPortraitImageInSquareViewHasHorizontalBars() {
        // 1:2 image in 200×200 view: displayed 100 wide, 200 tall, 50pt bars left/right.
        let view = CGSize(width: 200, height: 200)
        let image = CGSize(width: 200, height: 400)

        // Left edge of displayed image at x = 50 → normalized x = 0.
        let leftEdge = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 50, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(leftEdge.x, 0.0, accuracy: 0.001)

        // A touch in the right bar (x = 190) clamps to 1.
        let inBar = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 190, y: 100), viewSize: view, imageSize: image)
        XCTAssertEqual(inBar.x, 1.0, accuracy: 0.001)
    }

    func testDegenerateSizesDoNotCrash() {
        let p = PhotoLoupeGeometry.normalizedPoint(
            forViewPoint: CGPoint(x: 10, y: 10),
            viewSize: .zero,
            imageSize: .zero
        )
        XCTAssertTrue(p.x >= 0 && p.x <= 1)
        XCTAssertTrue(p.y >= 0 && p.y <= 1)
    }
}
