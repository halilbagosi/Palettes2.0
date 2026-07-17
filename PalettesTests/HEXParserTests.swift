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

    // MARK: - Color(hex:) rejection
    // NOTE: 3-digit and 8-digit (alpha) hex strings are rejected under
    // CURRENT behavior — only exactly 6 hex digits (post "#" stripping) parse.
    // Plan 005 is expected to change this.

    func testRejectsThreeDigitHex() {
        XCTAssertNil(Color(hex: "#FFF"))
    }

    func testRejectsEightDigitHexWithAlpha() {
        XCTAssertNil(Color(hex: "#FF5D00AA"))
    }

    func testRejectsNonHexCharacters() {
        XCTAssertNil(Color(hex: "GGGGGG"))
    }

    func testRejectsEmptyString() {
        XCTAssertNil(Color(hex: ""))
    }
}
