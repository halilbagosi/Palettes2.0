//
//  ColorAdjustmentTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class ColorAdjustmentTests: XCTestCase {

    // MARK: - hexString round-trip

    func testHexStringRoundTripsRGB() {
        let hex = ColorAdjustment.hexString(r: 255, g: 93, b: 0)
        XCTAssertEqual(hex, "#FF5D00")
    }

    func testHexStringRoundTripsBlack() {
        XCTAssertEqual(ColorAdjustment.hexString(r: 0, g: 0, b: 0), "#000000")
    }

    // MARK: - apply() with neutral (0.5) deltas is (approximately) identity

    func testApplyWithNeutralSlidersIsApproximatelyIdentity() {
        let base = (r: 255.0, g: 93.0, b: 0.0)
        let result = ColorAdjustment.apply(
            baseR: base.r, baseG: base.g, baseB: base.b,
            temperature: 0.5, saturation: 0.5, brightness: 0.5
        )
        // The HSB round-trip through UIColor can introduce small floating
        // point drift, so we assert closeness rather than exact equality.
        XCTAssertEqual(result.r, base.r, accuracy: 1.0)
        XCTAssertEqual(result.g, base.g, accuracy: 1.0)
        XCTAssertEqual(result.b, base.b, accuracy: 1.0)
    }

    // MARK: - apply() clamps at bounds without crashing

    func testApplyClampsAtMinimumSliderValues() {
        let result = ColorAdjustment.apply(
            baseR: 10, baseG: 10, baseB: 10,
            temperature: 0.0, saturation: 0.0, brightness: 0.0
        )
        XCTAssertGreaterThanOrEqual(result.r, 0)
        XCTAssertGreaterThanOrEqual(result.g, 0)
        XCTAssertGreaterThanOrEqual(result.b, 0)
        XCTAssertLessThanOrEqual(result.r, 255)
        XCTAssertLessThanOrEqual(result.g, 255)
        XCTAssertLessThanOrEqual(result.b, 255)

        // Output must still be a valid 6-digit hex string.
        let hex = ColorAdjustment.hexString(r: result.r, g: result.g, b: result.b)
        XCTAssertNotNil(Color(hex: hex))
    }

    func testApplyClampsAtMaximumSliderValues() {
        let result = ColorAdjustment.apply(
            baseR: 240, baseG: 240, baseB: 240,
            temperature: 1.0, saturation: 1.0, brightness: 1.0
        )
        XCTAssertGreaterThanOrEqual(result.r, 0)
        XCTAssertGreaterThanOrEqual(result.g, 0)
        XCTAssertGreaterThanOrEqual(result.b, 0)
        XCTAssertLessThanOrEqual(result.r, 255)
        XCTAssertLessThanOrEqual(result.g, 255)
        XCTAssertLessThanOrEqual(result.b, 255)

        let hex = ColorAdjustment.hexString(r: result.r, g: result.g, b: result.b)
        XCTAssertNotNil(Color(hex: hex))
    }

    // MARK: - offsetLabel

    func testOffsetLabelAtNeutralIsNeutral() {
        XCTAssertEqual(ColorAdjustment.offsetLabel(0.5), "Neutral")
    }

    func testOffsetLabelPositiveUsesCustomSuffix() {
        XCTAssertEqual(ColorAdjustment.offsetLabel(0.7, positive: "warm", negative: "cool"), "+20 warm")
    }

    func testOffsetLabelNegativeUsesCustomSuffix() {
        XCTAssertEqual(ColorAdjustment.offsetLabel(0.3, positive: "warm", negative: "cool"), "-20 cool")
    }
}
