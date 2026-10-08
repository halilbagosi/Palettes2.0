//
//  OKLCHTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class OKLCHTests: XCTestCase {

    /// Reference values for sRGB red, from Björn Ottosson's OKLab definition.
    func testRedMatchesPublishedOKLCHValues() {
        let red = OKLCH(hex: "#FF0000")!
        XCTAssertEqual(red.L, 0.6280, accuracy: 0.001)
        XCTAssertEqual(red.C, 0.2577, accuracy: 0.001)
        XCTAssertEqual(red.h, 29.23, accuracy: 0.1)
    }

    func testWhiteAndBlackHaveNoChroma() {
        let white = OKLCH(hex: "#FFFFFF")!
        XCTAssertEqual(white.L, 1, accuracy: 0.0001)
        XCTAssertEqual(white.C, 0, accuracy: 0.0001)
        let black = OKLCH(hex: "#000000")!
        XCTAssertEqual(black.L, 0, accuracy: 0.0001)
        XCTAssertEqual(black.C, 0, accuracy: 0.0001)
    }

    func testHexRoundTripsExactly() {
        for hex in ["#3366CC", "#E2683C", "#3E8E5E", "#D9B44A", "#000000", "#FFFFFF", "#7F7F7F", "#010203"] {
            XCTAssertEqual(OKLCH(hex: hex)?.hex, hex)
        }
    }

    func testParsesLowercaseAndRejectsMalformedHex() {
        XCTAssertEqual(OKLCH(hex: "3366cc")?.hex, "#3366CC")
        XCTAssertNil(OKLCH(hex: "#12345"))
        XCTAssertNil(OKLCH(hex: "nothex"))
    }

    /// Clipping a too-saturated color must keep its lightness and hue, so a
    /// palette's lightness ladder and hue family survive the gamut.
    func testGamutMappingKeepsLightnessAndHue() {
        let wild = OKLCH(L: 0.7, C: 0.35, h: 145)
        XCTAssertFalse(wild.isInSRGBGamut)
        let mapped = wild.gamutMapped()
        XCTAssertTrue(mapped.isInSRGBGamut)
        XCTAssertEqual(mapped.L, 0.7, accuracy: 1e-9)
        XCTAssertEqual(mapped.h, 145, accuracy: 1e-9)
        XCTAssertLessThan(mapped.C, 0.35)
        XCTAssertGreaterThan(mapped.C, 0.15)
    }

    func testHueDistanceWrapsAroundTheCircle() {
        XCTAssertEqual(OKLCH.hueDistance(350, 10), 20, accuracy: 1e-9)
        XCTAssertEqual(OKLCH.hueDistance(0, 180), 180, accuracy: 1e-9)
        XCTAssertEqual(OKLCH.wrap(-30), 330, accuracy: 1e-9)
    }
}
