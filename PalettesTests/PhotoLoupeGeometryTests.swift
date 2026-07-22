//
//  PhotoLoupeGeometryTests.swift
//  PalettesTests
//

import XCTest
import CoreGraphics
@testable import Palettes

final class PhotoLoupeGeometryTests: XCTestCase {

    // MARK: - imageRect

    func testSquareImageInSquareViewFillsView() {
        let r = PhotoLoupeGeometry.imageRect(
            imageSize: CGSize(width: 500, height: 500),
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(r.minX, 0, accuracy: 0.001)
        XCTAssertEqual(r.minY, 0, accuracy: 0.001)
        XCTAssertEqual(r.width, 200, accuracy: 0.001)
        XCTAssertEqual(r.height, 200, accuracy: 0.001)
    }

    func testLandscapeImageInSquareViewHasVerticalBars() {
        // 2:1 image in 200×200 view: 200 wide, 100 tall, 50pt bars top/bottom.
        let r = PhotoLoupeGeometry.imageRect(
            imageSize: CGSize(width: 400, height: 200),
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(r.minX, 0, accuracy: 0.001)
        XCTAssertEqual(r.minY, 50, accuracy: 0.001)
        XCTAssertEqual(r.width, 200, accuracy: 0.001)
        XCTAssertEqual(r.height, 100, accuracy: 0.001)
    }

    func testPortraitImageInSquareViewHasHorizontalBars() {
        // 1:2 image in 200×200 view: 100 wide, 200 tall, 50pt bars left/right.
        let r = PhotoLoupeGeometry.imageRect(
            imageSize: CGSize(width: 200, height: 400),
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(r.minX, 50, accuracy: 0.001)
        XCTAssertEqual(r.minY, 0, accuracy: 0.001)
        XCTAssertEqual(r.width, 100, accuracy: 0.001)
        XCTAssertEqual(r.height, 200, accuracy: 0.001)
    }

    func testDegenerateSizesReturnViewRect() {
        let r = PhotoLoupeGeometry.imageRect(imageSize: .zero, in: CGSize(width: 10, height: 20))
        XCTAssertEqual(r.width, 10, accuracy: 0.001)
        XCTAssertEqual(r.height, 20, accuracy: 0.001)
    }

    // MARK: - normalizedPoint(in:at:)

    func testNormalizedCenter() {
        let rect = CGRect(x: 0, y: 50, width: 200, height: 100)
        let p = PhotoLoupeGeometry.normalizedPoint(in: rect, at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(p.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.5, accuracy: 0.001)
    }

    func testNormalizedTopLeftCorner() {
        let rect = CGRect(x: 50, y: 0, width: 100, height: 200)
        let p = PhotoLoupeGeometry.normalizedPoint(in: rect, at: CGPoint(x: 50, y: 0))
        XCTAssertEqual(p.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 0.0, accuracy: 0.001)
    }

    func testNormalizedClampsPointOutsideRect() {
        let rect = CGRect(x: 50, y: 0, width: 100, height: 200)
        // Far left of the image rect clamps to 0; far below clamps to 1.
        let p = PhotoLoupeGeometry.normalizedPoint(in: rect, at: CGPoint(x: -20, y: 999))
        XCTAssertEqual(p.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 1.0, accuracy: 0.001)
    }
}
