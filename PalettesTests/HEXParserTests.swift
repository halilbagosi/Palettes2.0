//
//  HEXParserTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class HEXParserTests: XCTestCase {

    // MARK: - Color(hex:) acceptance

    func testAcceptsSixDigitHexWithoutHash() {
        XCTAssertNotNil(Color(hex: "FF5D00"))
    }

    func testAcceptsSixDigitHexWithHash() {
        XCTAssertNotNil(Color(hex: "#FF5D00"))
    }

    func testAcceptsLowercaseHex() {
        XCTAssertNotNil(Color(hex: "#ff5d00"))
    }

    func testAcceptsHexWithSurroundingWhitespace() {
        XCTAssertNotNil(Color(hex: "  #FF5D00  "))
    }

    // MARK: - Color(hex:) shorthand acceptance
    // NOTE: Per plan 005, 3/4/8-digit hex strings are now accepted.
    // 3-digit (RGB) and 4-digit (RGBA) forms expand each digit; 8-digit
    // (RRGGBBAA) parses the RGB component and discards alpha (not
    // representable in the data model).

    func testAcceptsThreeDigitHexAndExpandsToSixDigitEquivalent() {
        let shorthand = Color(hex: "#FFF")
        let expanded = Color(hex: "#FFFFFF")
        XCTAssertNotNil(shorthand)
        XCTAssertNotNil(expanded)
        XCTAssertEqual(shorthand, expanded)
    }

    func testAcceptsFourDigitHexAndDiscardsAlpha() {
        let shorthand = Color(hex: "#F0AC")
        let expanded = Color(hex: "#FF00AA")
        XCTAssertNotNil(shorthand)
        XCTAssertNotNil(expanded)
        XCTAssertEqual(shorthand, expanded)
    }

    func testAcceptsEightDigitHexAndDiscardsAlpha() {
        let withAlpha = Color(hex: "#FF5D00AA")
        let withoutAlpha = Color(hex: "#FF5D00")
        XCTAssertNotNil(withAlpha)
        XCTAssertNotNil(withoutAlpha)
        XCTAssertEqual(withAlpha, withoutAlpha)
    }

    // MARK: - Color(hex:) rejection

    func testRejectsNonHexCharacters() {
        XCTAssertNil(Color(hex: "GGGGGG"))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(Color(hex: ""))
    }

    func testRejectsFiveDigitHex() {
        XCTAssertNil(Color(hex: "#FFFFF"))
    }

    func testRejectsSevenDigitHex() {
        XCTAssertNil(Color(hex: "#FFFFFFF"))
    }

    func testRejectsThreeLetterNonHex() {
        XCTAssertNil(Color(hex: "GGG"))
    }
}
