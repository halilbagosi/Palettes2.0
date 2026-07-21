//
//  PaletteGeneratorTests.swift
//  PalettesTests
//

import XCTest
import UIKit
import SwiftUI
@testable import Palettes

final class PaletteGeneratorTests: XCTestCase {

    // MARK: - Regression: empty base colors must still fill to size

    /// Regression test for the cold-start bug: with no base colors selected
    /// (the default form state, and what `GeneratePaletteIntent` always
    /// passes), `fillToTarget`'s old `!colors.isEmpty` guard skipped
    /// harmony-plan slot filling entirely, so generation returned a palette
    /// with zero colors. Exercises the same simulator mock path the test
    /// suite actually runs under.
    @available(iOS 26.0, *)
    @MainActor
    func testMockGenerateWithNoBaseColorsFillsToRequestedSize() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [],
            size: 6,
            vibe: nil
        )
        XCTAssertEqual(result.colors.count, 6)
        XCTAssertEqual(result.hexCodes.count, 6)
        XCTAssertEqual(result.colorNames.count, 6)
    }

    // MARK: - Bounded repair loop

    /// A fixable case: four perceptually-identical dark colors with nothing
    /// locked. `repairViolations` should converge to a violation-free
    /// palette of the requested size using the real harmony-plan fallback,
    /// well within its two-pass cap.
    @available(iOS 26.0, *)
    func testRepairViolationsConvergesForAFixableCase() {
        var colors = ["#101010", "#111111", "#0F0F0F", "#101112"].map { Color(hex: $0)! }
        var hexCodes = ["#101010", "#111111", "#0F0F0F", "#101112"]
        var colorNames = ["A", "B", "C", "D"]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            seen: &seen,
            lockedCount: 0,
            targetCount: 4,
            fallbackPlan: nil,
            planSeed: 42
        )

        XCTAssertEqual(colors.count, 4, "fill guarantee must still hold after repair")
        XCTAssertEqual(hexCodes.count, 4)
        XCTAssertEqual(colorNames.count, 4)
        XCTAssertEqual(seen.count, 4)
        XCTAssertTrue(
            PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0).isEmpty,
            "expected the real harmony-plan fallback to resolve all violations within the pass cap"
        )
    }

    /// An adversarial case that can never converge: the fallback plan itself
    /// reintroduces near-duplicate dark colors every time it's consumed, so
    /// violations persist after every repair pass. This proves the loop is
    /// hard-capped at two passes (never unbounded) and that the palette is
    /// accepted as-is — fill guarantee intact, no crash, no throw — rather
    /// than looping forever or failing when violations can't be fully
    /// resolved.
    @available(iOS 26.0, *)
    func testRepairViolationsTerminatesAndAcceptsPaletteWhenUnresolvable() {
        var colors = ["#101010", "#111111", "#0F0F0F", "#101112"].map { Color(hex: $0)! }
        var hexCodes = ["#101010", "#111111", "#0F0F0F", "#101112"]
        var colorNames = ["A", "B", "C", "D"]
        var seen = Set(hexCodes)

        // Near-black grays, one shade apart from the surviving anchor and
        // from each other — perceptually indistinct, so every pass that
        // consumes this plan reintroduces the same violations it just
        // repaired.
        let stubbornPlan = HarmonyPlan(
            resolvedScheme: .monochromatic,
            slots: [
                HarmonySlot(hue: 0, saturation: 0, brightness: 18.0 / 255.0, role: nil),
                HarmonySlot(hue: 0, saturation: 0, brightness: 19.0 / 255.0, role: nil),
                HarmonySlot(hue: 0, saturation: 0, brightness: 20.0 / 255.0, role: nil),
            ],
            roleForBase: [nil]
        )

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            seen: &seen,
            lockedCount: 0,
            targetCount: 4,
            fallbackPlan: stubbornPlan,
            planSeed: 7
        )

        // Fill guarantee holds even though distinctness could not be fully
        // repaired — the function accepted the palette rather than looping
        // forever or throwing.
        XCTAssertEqual(colors.count, 4)
        XCTAssertEqual(hexCodes.count, 4)
        XCTAssertEqual(colorNames.count, 4)
    }

    /// Regression test for the refactor bug: with the loop shaped as
    /// `while !bad.isEmpty && repairPass < 2`, a starting state with ZERO
    /// violations never entered the loop body at all, so `fillToTarget`
    /// never ran — silently dropping the "always reach the requested size"
    /// guarantee whenever the model simply returned fewer (but individually
    /// valid) colors than requested. The fill step must be unconditional;
    /// only the re-check/early-exit is conditional on violations.
    @available(iOS 26.0, *)
    func testRepairViolationsPadsWhenNoViolationsButShortOfTarget() {
        var colors = ["#3060A0", "#A03060", "#60A030"].map { Color(hex: $0)! }
        var hexCodes = ["#3060A0", "#A03060", "#60A030"]
        var colorNames = ["A", "B", "C"]
        var seen = Set(hexCodes)

        // Sanity: this starting state has no violations at all (n < 4, so
        // the brightness-span rule doesn't apply, and the hues are distinct)
        // — the exact condition that used to make the loop skip entirely.
        XCTAssertTrue(PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0).isEmpty)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            seen: &seen,
            lockedCount: 0,
            targetCount: 5,
            fallbackPlan: nil,
            planSeed: 123
        )

        XCTAssertEqual(colors.count, 5, "fillToTarget must run even when there were no violations to repair")
        XCTAssertEqual(hexCodes.count, 5)
        XCTAssertEqual(colorNames.count, 5)
    }

    /// The exact regression scenario from the review: the on-device model
    /// returns a single valid (non-violating) color against a requested
    /// size of 5. Pre-fix, `bad.isEmpty` on entry meant the loop body (and
    /// therefore `fillToTarget`) never ran, `colors.count` stayed at 1, and
    /// `generate()`'s `guard colors.count >= 2 else { throw
    /// AppError.generationFailed }` would have fired — a user-facing
    /// generation failure for an entirely ordinary case.
    @available(iOS 26.0, *)
    func testRepairViolationsFillsSingleValidColorToRequestedSizeWithoutThrowing() {
        var colors = [Color(hex: "#4A90D9")!]
        var hexCodes = ["#4A90D9"]
        var colorNames = ["Electric Blue"]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            seen: &seen,
            lockedCount: 0,
            targetCount: 5,
            fallbackPlan: nil,
            planSeed: 7
        )

        XCTAssertEqual(colors.count, 5, "a single valid color must still be padded to the requested size")
        XCTAssertEqual(hexCodes.count, 5)
        XCTAssertEqual(colorNames.count, 5)
        // The would-be-thrown guard in generate() is `colors.count >= 2`;
        // confirm we're well clear of it rather than stuck at 1.
        XCTAssertGreaterThanOrEqual(colors.count, 2)
    }
}
