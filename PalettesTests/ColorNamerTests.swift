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

    // MARK: - uniqueNames(forHexes:preferred:)

    /// Several distinct-but-similar blues (all nearest to "Steel Blue" or
    /// neighboring blue entries under plain nearest-match naming) must come
    /// back with all-different names once run through the palette-wide API.
    func testSimilarBluesYieldAllDifferentNames() {
        let hexes = ["#4A7BA6", "#5C8CB8", "#3A6B96", "#6D9DC9", "#2E5A86"]
        let names = ColorNamer.uniqueNames(forHexes: hexes)
        XCTAssertEqual(names.count, hexes.count)
        XCTAssertEqual(Set(names).count, names.count, "expected all-unique names, got \(names)")
    }

    /// A non-empty preferred (AI-supplied) name that doesn't collide with any
    /// other preferred name in the same call must be used exactly as given.
    func testPreferredNameIsPreservedVerbatimWhenUnique() {
        let hexes = ["#4A90D9", "#D94A90"]
        let preferred = ["Electric Blue", "Raspberry Pop"]
        let names = ColorNamer.uniqueNames(forHexes: hexes, preferred: preferred)
        XCTAssertEqual(names, preferred)
    }

    /// Two colors that both arrive with the SAME AI-supplied preferred name
    /// must not both keep it — the second occurrence must be disambiguated
    /// to something else, and no numeric suffix ("Name 2") may appear.
    func testDuplicatePreferredNameIsDisambiguated() {
        let hexes = ["#4A90D9", "#4A0A0A"]
        let preferred = ["Ocean Blue", "Ocean Blue"]
        let names = ColorNamer.uniqueNames(forHexes: hexes, preferred: preferred)
        XCTAssertEqual(names.count, 2)
        XCTAssertEqual(Set(names).count, 2, "duplicate preferred names must be disambiguated: \(names)")
        XCTAssertEqual(names[0], "Ocean Blue", "the first occurrence keeps the preferred name verbatim")
        XCTAssertNotEqual(names[1], "Ocean Blue")
        XCTAssertFalse(names[1].contains("2"), "must never use a numeric-suffix style disambiguation")
    }

    /// Same input hexes (and same preferred array) must always produce the
    /// exact same output names — no hidden randomness.
    func testUniqueNamesIsDeterministic() {
        let hexes = ["#4A7BA6", "#5C8CB8", "#3A6B96", "#123456", "#ABCDEF"]
        let first = ColorNamer.uniqueNames(forHexes: hexes)
        let second = ColorNamer.uniqueNames(forHexes: hexes)
        XCTAssertEqual(first, second)
    }

    /// A color quite far (in Lab) from its nearest dictionary entry should
    /// get a descriptive modifier prefix rather than the bare entry name.
    func testDescriptiveModifierAppearsForColorsThatDeviateFromTheirNearestEntry() {
        // A muted warm gray-brown: its nearest dictionary entry ("Dark
        // Silver") is close in hue but meaningfully off in lightness/chroma,
        // so it should pick up a modifier rather than the bare entry name.
        let names = ColorNamer.uniqueNames(forHexes: ["#7A6F5D"])
        XCTAssertTrue(names[0].contains(" "), "expected a modifier + entry name, got \(names[0])")
    }

    /// A color essentially identical to a dictionary entry should NOT get a
    /// modifier prefix — the plain entry name is accurate enough.
    func testNoModifierWhenVeryCloseToNearestEntry() {
        let names = ColorNamer.uniqueNames(forHexes: ["#FF0000"])
        XCTAssertEqual(names[0], "Red")
    }

    /// Empty-string preferred entries are treated the same as nil — they
    /// must not be echoed back verbatim as the final name.
    func testEmptyPreferredFallsBackToDescriptiveName() {
        let names = ColorNamer.uniqueNames(forHexes: ["#FF0000"], preferred: [""])
        XCTAssertEqual(names[0], "Red")
    }

}
