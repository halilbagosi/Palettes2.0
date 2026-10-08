//
//  SchemeFidelityTests.swift
//  PalettesTests
//
//  Regression tests for the bug where a generated palette left the harmony
//  family the user selected. `ColorHarmony.plan`'s own slots were always
//  on-scheme (the existing ColorHarmonyTests covered that), but the SHIPPED
//  palette wasn't: `fillToTarget` dropped any plan slot that read as a
//  near-duplicate of a color already placed, then padded the shortfall by
//  rotating hue by the golden ratio (~137 degrees per step) — putting an
//  unrelated red in the middle of a monochromatic blue palette, and
//  off-family colors in every other scheme too.
//
//  These tests therefore assert on the FINAL palette, not on the plan.
//

import XCTest
import SwiftUI
import UIKit
@testable import Palettes

@available(iOS 26.0, *)
final class SchemeFidelityTests: XCTestCase {

    private let base = "#3366CC"
    private let sizes = [4, 6, 8, 12]

    private func hsb(of hex: String) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hexForFidelity: hex).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h * 360, s, b)
    }

    private func angularDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = abs(a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    /// Hue offsets from the base that a scheme is allowed to land on. Jitter
    /// is +/-6 degrees in `ColorHarmony`, so 10 leaves a little headroom
    /// without admitting a neighbouring scheme's offsets.
    ///
    /// 0 is always allowed: the user's locked base color ships verbatim at
    /// its own hue in every scheme.
    private func allowedOffsets(for scheme: HarmonyScheme) -> [CGFloat] {
        switch scheme {
        case .monochromatic: return [0]
        case .complementary: return [0, 180]
        case .splitComplementary: return [0, 150, 210]
        case .triadic: return [0, 120, 240]
        case .analogous: return [0, -33, -15, 15, 33]
        case .uiLight, .uiDark: return [0]
        case .auto: return []
        }
    }

    /// Analogous is a continuous band rather than discrete offsets — its
    /// spec bound is "within 40 degrees of the base" — so its offsets are
    /// checked with enough slack to cover the gaps between them.
    private func tolerance(for scheme: HarmonyScheme) -> CGFloat {
        scheme == .analogous ? 12 : 10
    }

    private func generate(scheme: HarmonyScheme, size: Int) async throws -> PaletteViewModel {
        try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: base, name: "Ocean Blue")],
            size: size,
            vibe: nil,
            scheme: scheme
        )
    }

    // MARK: - Every scheme ships only in-family hues

    /// The headline regression: every color in the shipped palette must sit
    /// on one of its scheme's hue offsets from the base.
    ///
    /// Colors below 0.25 saturation are exempt — hue is meaningless for a
    /// near-neutral, and `ColorHarmony` deliberately reserves desaturated
    /// Background/Text slots for `.splitComplementary` at size >= 5.
    func testEverySchemeShipsOnlyInFamilyHues() async throws {
        let baseHue = hsb(of: base).h
        for scheme in HarmonyScheme.allCases where scheme != .auto {
            let offsets = allowedOffsets(for: scheme)
            let tolerance = tolerance(for: scheme)
            for size in sizes {
                // Several runs: the seed is random per generation, and the
                // old bug only surfaced on runs where a plan slot happened to
                // be rejected by the perceptual gate.
                for run in 0..<5 {
                    let palette = try await generate(scheme: scheme, size: size)
                    for hex in palette.hexCodes {
                        let color = hsb(of: hex)
                        guard color.s >= 0.25 else { continue }
                        let bestOffset = offsets.min { a, b in
                            angularDelta(color.h, baseHue + a) < angularDelta(color.h, baseHue + b)
                        }
                        let delta = angularDelta(color.h, baseHue + (bestOffset ?? 0))
                        XCTAssertLessThanOrEqual(
                            delta,
                            tolerance,
                            "\(scheme.rawValue) size \(size) run \(run) shipped \(hex), \(Int(delta))° off every allowed offset — palette: \(palette.hexCodes)"
                        )
                    }
                }
            }
        }
    }

    /// The exact user-visible symptom: a monochromatic palette must be one
    /// hue. Pre-fix, sizes 4-6 reliably shipped a golden-ratio red (~137°
    /// off) alongside the blue.
    func testMonochromaticShipsASingleHue() async throws {
        let baseHue = hsb(of: base).h
        for size in sizes {
            for run in 0..<5 {
                let palette = try await generate(scheme: .monochromatic, size: size)
                for hex in palette.hexCodes {
                    let color = hsb(of: hex)
                    guard color.s >= 0.25 else { continue }
                    XCTAssertLessThanOrEqual(
                        angularDelta(color.h, baseHue),
                        10,
                        "monochromatic size \(size) run \(run) shipped off-hue \(hex) — palette: \(palette.hexCodes)"
                    )
                }
            }
        }
    }

    /// A monochromatic palette should still read as a ladder: staying on one
    /// hue must not collapse the palette into one tone.
    func testMonochromaticStillSpreadsBrightness() async throws {
        for size in [4, 6, 8] {
            let palette = try await generate(scheme: .monochromatic, size: size)
            let brightnesses = palette.hexCodes.map { hsb(of: $0).b }
            let spread = (brightnesses.max() ?? 0) - (brightnesses.min() ?? 0)
            XCTAssertGreaterThanOrEqual(spread, 0.35, "monochromatic size \(size) is too flat: \(palette.hexCodes)")
        }
    }

    /// Multiple selected bases are separate monochromatic families. The
    /// final (not merely planned) palette must draw evenly from each one.
    @MainActor
    func testMultipleSelectedBasesReceiveBalancedMonochromaticTones() async throws {
        let bases = ["#3366CC", "#CC6633"]
        let baseHues = bases.map { hsb(of: $0).h }
        let palette = try await PaletteGenerator.generate(
            baseColors: [
                PaletteGenerator.BaseColor(hex: bases[0], name: "Ocean Blue"),
                PaletteGenerator.BaseColor(hex: bases[1], name: "Clay Orange"),
            ],
            size: 8,
            vibe: nil,
            scheme: .monochromatic
        )

        XCTAssertEqual(palette.hexCodes.count, 8)
        var contributions = Array(repeating: 0, count: bases.count)
        for hex in palette.hexCodes.dropFirst(bases.count) {
            let hue = hsb(of: hex).h
            let closestBase = baseHues.indices.min { left, right in
                angularDelta(hue, baseHues[left]) < angularDelta(hue, baseHues[right])
            }!
            XCTAssertLessThanOrEqual(
                angularDelta(hue, baseHues[closestBase]),
                10,
                "generated monochromatic tone \(hex) is not in either selected family: \(palette.hexCodes)"
            )
            contributions[closestBase] += 1
        }
        XCTAssertEqual(contributions, [3, 3])
    }

    // MARK: - Staying in-family must not cost the count guarantee

    /// Dropping the golden-ratio fallback must not resurrect the old
    /// "palette ships short" bug: continuing the plan's own ladder has to
    /// supply enough distinct in-family colors to hit the requested size.
    func testEverySchemeStillReachesRequestedSize() async throws {
        for scheme in HarmonyScheme.allCases {
            for size in sizes {
                let palette = try await generate(scheme: scheme, size: size)
                XCTAssertEqual(
                    palette.hexCodes.count,
                    size,
                    "\(scheme.rawValue) shipped \(palette.hexCodes.count) of \(size): \(palette.hexCodes)"
                )
            }
        }
    }

    /// Staying in-family must not start shipping colors that read as the
    /// same color.
    ///
    /// At sizes a family can comfortably supply, the full deltaE 12 floor
    /// still holds. At sizes where it can't — a 12-color monochromatic
    /// palette is one hue asked for twelve distinguishable steps — the fill
    /// relaxes toward 6 rather than reaching outside the family, so the
    /// universal guarantee is the lower floor: always a visible step, never
    /// a repeat.
    ///
    /// Sampled repeatedly because the plan seed is random per generation: a
    /// single sample let a ~14% monochromatic size-6 failure (the fill
    /// relaxing to 9 when its candidate ladder had no pale tints) pass most
    /// runs and fail some.
    func testInFamilyFillsStayPerceptuallyDistinct() async throws {
        for scheme in HarmonyScheme.allCases {
            for size in sizes {
                for run in 0..<20 {
                    let palette = try await generate(scheme: scheme, size: size)
                    let hexes = palette.hexCodes
                    let floor: Double = size <= 6 ? PaletteValidation.minDeltaE : 6
                    for i in 0..<hexes.count {
                        for j in (i + 1)..<hexes.count {
                            XCTAssertGreaterThanOrEqual(
                                ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j]),
                                floor,
                                "\(scheme.rawValue) size \(size) run \(run) shipped near-duplicates \(hexes[i])/\(hexes[j])"
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Plan extension

    /// `extraSlots` is what replaced the golden-ratio rotation: it must
    /// continue the plan's own scheme, and it must keep producing *new*
    /// slots rather than repeating the ones the plan already emitted.
    func testExtraSlotsContinueTheSameFamily() {
        let baseHue = hsb(of: base).h
        for scheme in HarmonyScheme.allCases where scheme != .auto {
            let plan = ColorHarmony.plan(baseHexes: [base], size: 6, scheme: scheme, seed: 99)
            let extras = ColorHarmony.extraSlots(for: plan, count: 24)
            XCTAssertEqual(extras.count, 24)

            let offsets = allowedOffsets(for: scheme)
            let tolerance = tolerance(for: scheme)
            for slot in extras {
                let color = hsb(of: slot.hex)
                guard color.s >= 0.25 else { continue }
                let bestOffset = offsets.min { a, b in
                    angularDelta(color.h, baseHue + a) < angularDelta(color.h, baseHue + b)
                }
                XCTAssertLessThanOrEqual(
                    angularDelta(color.h, baseHue + (bestOffset ?? 0)),
                    tolerance,
                    "\(scheme.rawValue) extension slot \(slot.hex) left the family"
                )
            }

            // Extensions carry no role — roles belong to the deliberate plan.
            XCTAssertTrue(extras.allSatisfy { $0.role == nil })

            // And they continue past the plan rather than repeating it.
            let planHexes = Set(plan.slots.map(\.hex))
            let overlap = extras.filter { planHexes.contains($0.hex) }
            XCTAssertTrue(overlap.isEmpty, "\(scheme.rawValue) extension replayed plan slots: \(overlap.map(\.hex))")
        }
    }

    /// Same seed and index must give the same slot, so an extension is
    /// reproducible rather than dependent on how many slots came before it.
    func testExtraSlotsAreDeterministic() {
        let plan = ColorHarmony.plan(baseHexes: [base], size: 6, scheme: .triadic, seed: 5)
        XCTAssertEqual(ColorHarmony.extraSlots(for: plan, count: 8), ColorHarmony.extraSlots(for: plan, count: 8))
    }

    /// A hand-built plan carries no base hexes, so there is nothing to
    /// extend — it must return empty rather than inventing a family.
    func testExtraSlotsEmptyForPlanWithoutBase() {
        let handBuilt = HarmonyPlan(
            resolvedScheme: .analogous,
            slots: [HarmonySlot(hue: 0.5, saturation: 0.5, brightness: 0.5, role: nil)],
            roleForBase: [nil]
        )
        XCTAssertTrue(ColorHarmony.extraSlots(for: handBuilt, count: 10).isEmpty)
    }

    // MARK: - Repair honors the selected scheme

    /// `repairViolations` used to synthesize its ad-hoc plan with `.auto`
    /// hardcoded, so a repair could re-resolve to a different scheme and pull
    /// the palette out of the family the user picked.
    func testRepairHonorsSelectedScheme() {
        var colors = [Color(hex: base)!]
        var hexCodes = [base]
        var colorNames = ["Ocean Blue"]
        var roles = [""]
        var seen = Set(hexCodes)

        PaletteGenerator.repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &roles,
            seen: &seen,
            lockedCount: 1,
            targetCount: 6,
            fallbackPlan: nil,
            planSeed: 11,
            scheme: .monochromatic
        )

        XCTAssertEqual(hexCodes.count, 6)
        let baseHue = hsb(of: base).h
        for hex in hexCodes {
            let color = hsb(of: hex)
            guard color.s >= 0.25 else { continue }
            XCTAssertLessThanOrEqual(
                angularDelta(color.h, baseHue),
                10,
                "repair left the monochromatic family with \(hex): \(hexCodes)"
            )
        }
    }
}

private extension UIColor {
    convenience init(hexForFidelity hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h.removeAll { $0 == "#" }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
