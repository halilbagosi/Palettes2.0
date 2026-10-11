//
//  ColorVocabularyTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class ColorVocabularyTests: XCTestCase {

    func testReferenceColorsLandInTheirFamilies() {
        let expected: [(String, ColorVocabulary.Family)] = [
            ("#FF0000", .red), ("#FFA500", .orange), ("#FFFF00", .yellow), ("#00FF00", .green),
            ("#008080", .teal), ("#0000FF", .blue), ("#800080", .purple), ("#FFC0CB", .pink),
        ]
        for (hex, family) in expected {
            XCTAssertEqual(ColorVocabulary.family(forHue: OKLCH(hex: hex)!.h), family, hex)
        }
    }

    func testRingDistanceWraps() {
        XCTAssertEqual(ColorVocabulary.ringDistance(.pink, .purple), 1)
        XCTAssertEqual(ColorVocabulary.ringDistance(.red, .teal), 4)
        XCTAssertEqual(ColorVocabulary.ringDistance(.blue, .blue), 0)
    }

    func testDescriptionsComeFromTheSwatch() {
        XCTAssertEqual(ColorVocabulary.describe(hex: "#2F6BD8"), "medium, vivid blue")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#808080"), "medium neutral grey")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#021741"), "very dark, moderate blue")
    }

    func testPlausibleNamesPass() {
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Ocean Blue", forHex: "#2F6BD8"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Terracotta", forHex: "#E2683C"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Blue Grey", forHex: "#6B7F8E"))
    }

    func testNamesThatContradictTheSwatchFail() {
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Blue Lagoon", forHex: "#E2683C"), "blue word on an orange")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Midnight Ink", forHex: "#F1F5FD"), "dark words on a near-white")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Pale Mist", forHex: "#021741"), "light words on a near-black")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Charcoal", forHex: "#2C7284"), "grey word on a saturated teal")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Vivid Coral", forHex: "#808080"), "a hue on a true grey")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Color 7", forHex: "#808080"), "digits")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "  ", forHex: "#808080"), "empty")
    }

    func testTitleColorWordsMustMatchThePalette() {
        let blues = ["#2E5F8A", "#3E7FB0", "#1E3F5A"]
        XCTAssertFalse(ColorVocabulary.isPlausibleTitle("Crimson Tide", forHexes: blues))
        XCTAssertTrue(ColorVocabulary.isPlausibleTitle("Blue Hour", forHexes: blues))
        XCTAssertTrue(ColorVocabulary.isPlausibleTitle("Harbor Dusk", forHexes: blues), "no color words")
    }
}
