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
        var colorRoles = ["", "", "", ""]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &colorRoles,
            seen: &seen,
            lockedCount: 0,
            targetCount: 4,
            fallbackPlan: nil,
            planSeed: 42
        )

        XCTAssertEqual(colors.count, 4, "fill guarantee must still hold after repair")
        XCTAssertEqual(hexCodes.count, 4)
        XCTAssertEqual(colorNames.count, 4)
        XCTAssertEqual(colorRoles.count, 4)
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
        var colorRoles = ["", "", "", ""]
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
            roles: &colorRoles,
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
        XCTAssertEqual(colorRoles.count, 4)
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
        var colorRoles = ["", "", ""]
        var seen = Set(hexCodes)

        // Sanity: this starting state has no violations at all (n < 4, so
        // the brightness-span rule doesn't apply, and the hues are distinct)
        // — the exact condition that used to make the loop skip entirely.
        XCTAssertTrue(PaletteValidation.violations(hexCodes: hexCodes, lockedCount: 0).isEmpty)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &colorRoles,
            seen: &seen,
            lockedCount: 0,
            targetCount: 5,
            fallbackPlan: nil,
            planSeed: 123
        )

        XCTAssertEqual(colors.count, 5, "fillToTarget must run even when there were no violations to repair")
        XCTAssertEqual(hexCodes.count, 5)
        XCTAssertEqual(colorNames.count, 5)
        XCTAssertEqual(colorRoles.count, 5)
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
        var colorRoles = [""]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &colorRoles,
            seen: &seen,
            lockedCount: 0,
            targetCount: 5,
            fallbackPlan: nil,
            planSeed: 7
        )

        XCTAssertEqual(colors.count, 5, "a single valid color must still be padded to the requested size")
        XCTAssertEqual(hexCodes.count, 5)
        XCTAssertEqual(colorNames.count, 5)
        XCTAssertEqual(colorRoles.count, 5)
        // The would-be-thrown guard in generate() is `colors.count >= 2`;
        // confirm we're well clear of it rather than stuck at 1.
        XCTAssertGreaterThanOrEqual(colors.count, 2)
    }

    // MARK: - Role assignment on generation (Task 5)

    /// Generating from a single base color should tag it "Primary" — the
    /// first-priority role `ColorHarmony.roleForBases` assigns to base index 0.
    /// Exercises the simulator mock path (the only one reachable from tests),
    /// which always builds a `HarmonyPlan` from the locked base colors.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateFromOneBaseColorTagsFirstColorPrimary() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue")],
            size: 5,
            vibe: nil
        )
        XCTAssertEqual(result.paletteColors.first?.role, "Primary")
    }

    /// A single saturated base at size 6 resolves to `.splitComplementary`
    /// with reserved neutral slots (see `ColorHarmony.plan`'s `reserveNeutrals`
    /// gate), so the generated palette should contain both a "Background" and
    /// a "Text" role in addition to the base's "Primary".
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateSizeSixFromSaturatedBaseTagsBackgroundAndText() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue")],
            size: 6,
            vibe: nil
        )
        let roles = Set(result.paletteColors.compactMap(\.role))
        XCTAssertEqual(result.paletteColors.first?.role, "Primary")
        XCTAssertTrue(roles.contains("Background"), "expected a Background role among \(roles)")
        XCTAssertTrue(roles.contains("Text"), "expected a Text role among \(roles)")
    }

    /// With no base colors at all, there's no real anchor for `Primary`/
    /// `Secondary`/etc. to attach to — even though the mock path still
    /// synthesizes an internal plan to fill color *values*, none of that
    /// plan's roles should leak onto the result. Every role must stay nil.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateWithNoBaseColorsYieldsAllNilRoles() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [],
            size: 6,
            vibe: "sunset over the ocean"
        )
        XCTAssertTrue(result.paletteColors.allSatisfy { $0.role == nil })
    }

    /// The parallel-array alignment invariant now spans four arrays
    /// (colors/hexCodes/colorNames/roles). After `repairViolations` removes a
    /// perceptually-duplicate color and refills, the roles array must still
    /// be the same length and the survivor's role must not have shifted to
    /// the wrong color.
    @available(iOS 26.0, *)
    func testRepairViolationsKeepsRolesAlignedAfterRemovingAColor() {
        var colors = ["#3060A0", "#101010", "#111111", "#0F0F0F"].map { Color(hex: $0)! }
        var hexCodes = ["#3060A0", "#101010", "#111111", "#0F0F0F"]
        var colorNames = ["Primary Anchor", "B", "C", "D"]
        var colorRoles = ["Primary", "", "", ""]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &colorRoles,
            seen: &seen,
            lockedCount: 1,
            targetCount: 4,
            fallbackPlan: nil,
            planSeed: 99
        )

        XCTAssertEqual(colors.count, 4)
        XCTAssertEqual(hexCodes.count, 4)
        XCTAssertEqual(colorNames.count, 4)
        XCTAssertEqual(colorRoles.count, 4, "roles array must stay aligned with the other three parallel arrays after repair")
        // The locked anchor is never removed (indices below `lockedCount`
        // are excluded from `PaletteValidation.violations`), so its role
        // must still be at index 0 after any removal/refill.
        XCTAssertEqual(hexCodes[0], "#3060A0")
        XCTAssertEqual(colorRoles[0], "Primary")
    }

    /// Regression test for a review finding: with no locked/base colors at
    /// all (`lockedCount: 0`, `fallbackPlan: nil`), a shortfall still routes
    /// through `repairViolations`'s ad-hoc-plan branch at a target size that
    /// triggers `ColorHarmony.plan`'s `reserveNeutrals` gate (single
    /// surviving saturated color, size >= 5). That ad-hoc plan's slots carry
    /// real roles (Accent/Background/Text), and `fillToTarget` appended them
    /// verbatim — mislabeling colors in what should be an all-nil,
    /// anchor-less palette. `mockGenerate` already guarded this correctly by
    /// zeroing roles when `locked.isEmpty`; `repairViolations` must enforce
    /// the same invariant so the device `generate()` path (which routes
    /// through `repairViolations`, not `mockGenerate`) can't leak roles too.
    @available(iOS 26.0, *)
    func testRepairViolationsWithNoLockedColorsSuppressesRolesEvenWhenPlanFillTriggersNeutrals() {
        var colors = [Color(hex: "#3060A0")!]
        var hexCodes = ["#3060A0"]
        var colorNames = ["Ocean Blue"]
        var colorRoles = [""]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &colorRoles,
            seen: &seen,
            lockedCount: 0,
            targetCount: 6,
            fallbackPlan: nil,
            planSeed: 55
        )

        XCTAssertEqual(colors.count, 6, "fill guarantee must still hold")
        XCTAssertEqual(colorRoles.count, 6)
        XCTAssertTrue(
            colorRoles.allSatisfy { $0.isEmpty },
            "with no locked colors there is no real anchor for a role — expected all-empty roles, got \(colorRoles)"
        )
    }
}
