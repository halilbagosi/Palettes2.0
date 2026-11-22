import XCTest
@testable import Palettes

@MainActor
final class LooksAutoNamedTests: XCTestCase {
    private let hex = "#C45A6B"

    func testAutoNameIsDetected() {
        let auto = ColorNamer.name(forHex: hex)
        XCTAssertTrue(ColorNamer.looksAutoNamed(auto, hex: hex))
        XCTAssertTrue(ColorNamer.looksAutoNamed(auto.uppercased(), hex: hex), "case-insensitive")
        XCTAssertTrue(ColorNamer.looksAutoNamed("  \(auto) ", hex: hex), "whitespace ignored")
    }

    func testAutoNameAvoidingTakenIsDetected() {
        let first = ColorNamer.name(forHex: hex)
        let second = ColorNamer.name(forHex: hex, avoiding: [first])
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(ColorNamer.looksAutoNamed(second, hex: hex, taken: [first]))
    }

    func testNearestEntryNameIsDetected() throws {
        let nearest = try XCTUnwrap(ColorNamer.nearestEntryName(forHex: hex))
        XCTAssertTrue(ColorNamer.looksAutoNamed(nearest, hex: hex))
    }

    func testUserTypedNameIsNotAuto() {
        XCTAssertFalse(ColorNamer.looksAutoNamed("Grandma's Couch", hex: hex))
        XCTAssertFalse(ColorNamer.looksAutoNamed("", hex: hex))
    }

    /// A namer name that isn't this hex's today (an alternate picked to
    /// avoid a sibling, or an older namer's pick) still follows an edit.
    func testNamerShapedNameIsAuto() {
        let blue = ColorNamer.name(forHex: "#1E3A8A")
        XCTAssertTrue(ColorNamer.looksAutoNamed(blue, hex: hex))
        XCTAssertTrue(ColorNamer.looksAutoNamed("Soft Coral", hex: hex))
        XCTAssertTrue(ColorNamer.looksAutoNamed("Untitled", hex: hex))
        XCTAssertTrue(ColorNamer.looksAutoNamed("Crimson (#AB1234)", hex: hex))
    }

    func testNamesThatOnlyContainAColorWordAreNotAuto() {
        XCTAssertFalse(ColorNamer.looksAutoNamed("Brand Coral", hex: hex))
        XCTAssertFalse(ColorNamer.looksAutoNamed("Soft Soft Coral", hex: hex))
        XCTAssertFalse(ColorNamer.looksAutoNamed("Coral For Kitchen", hex: hex))
    }
}
