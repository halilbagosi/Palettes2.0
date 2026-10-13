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
        XCTAssertEqual(ColorVocabulary.describe(hex: "#2F6BD8"), "lightness=medium intensity=vivid hue=blue")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#808080"), "lightness=medium intensity=none hue=neutral grey")
        XCTAssertEqual(ColorVocabulary.describe(hex: "#021741"), "lightness=very dark intensity=moderate hue=blue")
    }

    /// The description fed to the model must not look like a color name, or
    /// the model echoes it ("gentle, muted aquamarine").
    func testDescriptionIsNotNameShaped() {
        for hex in ["#57BBFF", "#658BA8", "#CBAA8E", "#808080"] {
            let text = ColorVocabulary.describe(hex: hex)
            XCTAssertFalse(text.contains(","), text)
            XCTAssertFalse(ColorVocabulary.isCleanModelName(text), text)
        }
    }

    func testCleanModelNames() {
        for bad in ["gentle, muted aquamarine", "steady, muted cerulean", "soft, mellow tangerine", "rich, deep amber",
                    "Gentle Aquamarine", "Soft Blue", "Muted Teal", "Vivid Orange", "Light Sage", "Dark Plum",
                    "Four Word Name Here", ""] {
            XCTAssertFalse(ColorVocabulary.isCleanModelName(bad), bad)
        }
        for good in ["Terracotta", "Sage", "Cobalt", "Sky Blue", "Harbor Mist", "Warm Hearth", "Dusty Denim"] {
            XCTAssertTrue(ColorVocabulary.isCleanModelName(good), good)
        }
    }

    func testNounEnvelopes() {
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Tangerine", forHex: "#CBAA8E"), "tangerine is loud, this is tan")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Aquamarine", forHex: "#57BBFF"), "aquamarine is a green-cyan")
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Sky Blue", forHex: "#57BBFF"))
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Cerulean", forHex: "#658BA8"), "too dull for cerulean")
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Tangerine", forHex: "#FF9966"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Aquamarine", forHex: "#7FFFD4"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Turquoise", forHex: "#40E0D0"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Coral", forHex: "#FF7F50"))
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Coral", forHex: "#CBAA8E"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Tan", forHex: "#CBAA8E"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Beige", forHex: "#F5F5DC"))
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Beige", forHex: "#FF9966"), "beige is quiet")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Taupe", forHex: "#E2683C"))
        XCTAssertTrue(ColorVocabulary.isPlausible(name: "Navy", forHex: "#000080"))
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Navy", forHex: "#57BBFF"), "navy is dark")
        XCTAssertFalse(ColorVocabulary.isPlausible(name: "Midnight Blue", forHex: "#9FC5FF"))
    }

    func testNamesWithCommasFail() {
        XCTAssertFalse(ColorVocabulary.isCleanModelName("Sage, Green"))
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
