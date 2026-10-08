//
//  PaletteValidationTests.swift
//  PalettesTests
//

import XCTest
import UIKit
@testable import Palettes

final class PaletteValidationTests: XCTestCase {

    func testTooSimilarPairFlagsLaterNonLockedIndex() {
        let hexCodes = ["#FF0000", "#FE0102"]
        let violations = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0)
        XCTAssertEqual(violations, [1])
    }

    func testLockedColorsAreNeverFlaggedEvenIfSimilar() {
        // The first two colors are near-identical, but both are locked, so
        // neither may be flagged. The third color is clearly distinct.
        let hexCodes = ["#FF0000", "#FE0102", "#00FF00"]
        let violations = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 2)
        XCTAssertEqual(violations, [])
    }

    func testAllMidtonePaletteFlagsAViolationForBrightnessSpan() {
        // Four distinct hues, all with the same HSB brightness (0xB4/255 ≈
        // 0.706) — perceptually distinct pairwise, but the palette has no
        // light/dark spread at all (size >= 4 rule).
        let hexCodes = ["#B44040", "#40B440", "#4040B4", "#B4B440"]
        let violations = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0)
        XCTAssertFalse(violations.isEmpty, "expected at least one violation for a zero-spread midtone palette")
    }

    func testDistinctAndSpreadPaletteHasNoViolations() {
        // Distinct hues, and a wide light/dark brightness spread.
        let hexCodes = ["#B03030", "#30B030", "#202020", "#F5F0E0"]
        let violations = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0)
        XCTAssertEqual(violations, [])
    }

    func testDarkFlatPaletteNeverFlagsIndexZeroWithNoLocks() {
        // Four near-identical dark colors, lockedCount 0: with nothing
        // locked, the brightness-span rule's candidate range used to be
        // `0..<n`, so a flat/dark palette like this could have every index
        // flagged, leaving no anchor color to rebuild the repair from.
        // Index 0 must always survive as an anchor when lockedCount == 0.
        let hexCodes = ["#101010", "#111111", "#0F0F0F", "#101112"]
        let violations = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0)
        XCTAssertFalse(violations.contains(0), "index 0 must never be flagged when lockedCount == 0")
        XCTAssertLessThanOrEqual(violations.count, hexCodes.count - 1, "at most n-1 indices may be flagged")
    }
}
