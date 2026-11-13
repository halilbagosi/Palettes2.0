//
//  HexRGBTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class HexRGBTests: XCTestCase {

    func testParsesSixDigitHexWithOrWithoutHash() {
        XCTAssertTrue(HexRGB.components("#1A73A8")! == (26, 115, 168))
        XCTAssertTrue(HexRGB.components("1a73a8")! == (26, 115, 168))
    }

    func testExpandsShortHexAndDropsAlpha() {
        XCTAssertTrue(HexRGB.components("#FFF")! == (255, 255, 255))
        XCTAssertTrue(HexRGB.components("#F008")! == (255, 0, 0))
        XCTAssertTrue(HexRGB.components("#1A73A8FF")! == (26, 115, 168))
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(HexRGB.components("#12"))
        XCTAssertNil(HexRGB.components("zzzzzz"))
        XCTAssertNil(HexRGB.components("+12345"))
        XCTAssertNil(HexRGB.components(""))
    }

    func testLuminanceEndpoints() {
        XCTAssertEqual(HexRGB.luminance("#FFFFFF")!, 1, accuracy: 0.0001)
        XCTAssertEqual(HexRGB.luminance("#000000")!, 0, accuracy: 0.0001)
        XCTAssertNil(HexRGB.luminance("nope"))
    }

    func testIsLightPicksTheBetterContrast() {
        XCTAssertTrue(HexRGB.isLight("#FFFFFF"))
        XCTAssertTrue(HexRGB.isLight("#FFD60A"))
        XCTAssertFalse(HexRGB.isLight("#000000"))
        XCTAssertFalse(HexRGB.isLight("#1A73A8"))
    }

    func testMalformedHexIsTreatedAsFallbackGrey() {
        XCTAssertEqual(HexRGB.isLight("nope"), HexRGB.isLight(HexRGB.fallbackGrey))
    }
}
