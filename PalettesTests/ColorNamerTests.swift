//
//  ColorNamerTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ColorNamerTests: XCTestCase {

    // Three entries picked directly from the `namedColors` table in
    // HEXParser.swift (name, r, g, b in 0-255).
    private let white = (name: "White", hex: "FFFFFF")
    private let black = (name: "Black", hex: "000000")
    private let red = (name: "Red", hex: "FF0000")

    // MARK: - name(forHex:)

    func testNamesOwnHexAsWhite() {
        XCTAssertEqual(ColorNamer.name(forHex: white.hex), white.name)
    }

    func testNamesOwnHexAsBlack() {
        XCTAssertEqual(ColorNamer.name(forHex: black.hex), black.name)
    }

    func testNamesOwnHexAsRed() {
        XCTAssertEqual(ColorNamer.name(forHex: red.hex), red.name)
    }

    func testInvalidHexReturnsUnknown() {
        XCTAssertEqual(ColorNamer.name(forHex: "not-a-hex"), "Unknown")
    }

    func testNamingIsDeterministic() {
        let first = ColorNamer.name(forHex: "FF5D00")
        let second = ColorNamer.name(forHex: "FF5D00")
        XCTAssertEqual(first, second)
    }

    // MARK: - perceptualDistance

    func testDistanceBetweenIdenticalHexesIsZero() {
        XCTAssertEqual(ColorNamer.perceptualDistance(hex1: "FF5D00", hex2: "FF5D00"), 0, accuracy: 0.0001)
    }

    func testDistanceWithInvalidHexIsGreatestFiniteMagnitude() {
        XCTAssertEqual(ColorNamer.perceptualDistance(hex1: "FF5D00", hex2: "nope"), .greatestFiniteMagnitude)
    }

    func testDistanceIsSymmetric() {
        let a = ColorNamer.perceptualDistance(hex1: "FF5D00", hex2: "00A2FF")
        let b = ColorNamer.perceptualDistance(hex1: "00A2FF", hex2: "FF5D00")
        XCTAssertEqual(a, b, accuracy: 0.0001)
    }
}
