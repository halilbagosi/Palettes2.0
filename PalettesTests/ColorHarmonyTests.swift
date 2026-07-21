//
//  ColorHarmonyTests.swift
//  PalettesTests
//

import XCTest
import UIKit
@testable import Palettes

final class ColorHarmonyTests: XCTestCase {

    private func hue(of hex: String) -> CGFloat {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hexForTest: hex).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return h * 360
    }

    private func hsb(of hex: String) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hexForTest: hex).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h * 360, s, b)
    }

    private func angularDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = abs(a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    // MARK: - Scheme math

    func testComplementaryFirstSlotNear180() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000"], size: 3, scheme: .complementary, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .complementary)
        XCTAssertFalse(plan.slots.isEmpty)
        let baseHue = hue(of: "#FF0000")
        let delta = angularDelta(hue(of: plan.slots[0].hex), baseHue - 180)
        XCTAssertLessThanOrEqual(delta, 8)
    }

    func testSplitComplementaryOffsets() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000"], size: 3, scheme: .splitComplementary, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .splitComplementary)
        let baseHue = hue(of: "#FF0000")
        XCTAssertEqual(plan.slots.count, 2)
        let d0 = angularDelta(hue(of: plan.slots[0].hex), baseHue + 150)
        let d1 = angularDelta(hue(of: plan.slots[1].hex), baseHue + 210)
        XCTAssertLessThanOrEqual(d0, 8)
        XCTAssertLessThanOrEqual(d1, 8)
    }

    func testAnalogousWithin40Degrees() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000"], size: 4, scheme: .analogous, seed: 1)
        let baseHue = hue(of: "#FF0000")
        for slot in plan.slots {
            XCTAssertLessThanOrEqual(angularDelta(hue(of: slot.hex), baseHue), 40)
        }
    }

    func testTriadicOffsets120() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000"], size: 3, scheme: .triadic, seed: 1)
        let baseHue = hue(of: "#FF0000")
        XCTAssertEqual(plan.slots.count, 2)
        let d0 = angularDelta(hue(of: plan.slots[0].hex), baseHue + 120)
        let d1 = angularDelta(hue(of: plan.slots[1].hex), baseHue + 240)
        XCTAssertLessThanOrEqual(d0, 8)
        XCTAssertLessThanOrEqual(d1, 8)
    }

    func testMonochromaticHueCloseBrightnessSpread() {
        let plan = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .monochromatic, seed: 1)
        let baseHue = hue(of: "#3366CC")
        var brightnesses: [CGFloat] = []
        for slot in plan.slots {
            XCTAssertLessThanOrEqual(angularDelta(hue(of: slot.hex), baseHue), 8)
            brightnesses.append(hsb(of: slot.hex).b)
        }
        let spread = (brightnesses.max() ?? 0) - (brightnesses.min() ?? 0)
        XCTAssertGreaterThanOrEqual(spread, 0.3)
    }

    // MARK: - Determinism

    func testDeterminismSameSeed() {
        let plan1 = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .analogous, seed: 42)
        let plan2 = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .analogous, seed: 42)
        XCTAssertEqual(plan1, plan2)
    }

    func testDifferentSeedProducesDifferentSlots() {
        let plan1 = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .analogous, seed: 1)
        let plan2 = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .analogous, seed: 2)
        XCTAssertNotEqual(plan1, plan2)
    }

    // MARK: - Auto heuristics

    func testAutoNearNeutralPicksMonochromaticWithOneAccent() {
        let plan = ColorHarmony.plan(baseHexes: ["#808080"], size: 6, scheme: .auto, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .monochromatic)
        let accentSlots = plan.slots.filter { hsb(of: $0.hex).s >= 0.5 }
        XCTAssertEqual(accentSlots.count, 1)
    }

    func testAutoOppositeBasesPicksComplementaryFamily() {
        // #FF0000 (hue 0) and a hue ~180 apart, e.g. #00E5E5 (cyan-ish, hue ~180)
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000", "#00CFCF"], size: 6, scheme: .auto, seed: 1)
        XCTAssertTrue(plan.resolvedScheme == .complementary || plan.resolvedScheme == .splitComplementary)
    }

    func testAutoAdjacentBasesPicksAnalogous() {
        // #FF0000 (hue 0) and #FF6600 (hue ~24, within 40)
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000", "#FF6600"], size: 6, scheme: .auto, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .analogous)
    }

    func testAutoSingleSaturatedBaseSizeSixPicksSplitComplementaryWithNeutralSlots() {
        let plan = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .auto, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .splitComplementary)
        let hasBackground = plan.slots.contains { slot in
            let c = hsb(of: slot.hex)
            return slot.role == "Background" && c.s <= 0.08 && c.b >= 0.94
        }
        let hasText = plan.slots.contains { slot in
            slot.role == "Text" && hsb(of: slot.hex).b <= 0.22
        }
        XCTAssertTrue(hasBackground, "expected a Background-role neutral light slot")
        XCTAssertTrue(hasText, "expected a Text-role neutral dark slot")
    }

    func testAutoSingleSaturatedBaseSizeFiveStillReservesNeutralSlots() {
        // Boundary case: size == 5 with one base means slotCount (size -
        // baseCount) is only 4, but the spec's "size >= 5" neutral-reservation
        // heuristic must still key off the raw requested size, not slotCount.
        let plan = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 5, scheme: .auto, seed: 1)
        XCTAssertEqual(plan.resolvedScheme, .splitComplementary)
        let hasBackground = plan.slots.contains { slot in
            let c = hsb(of: slot.hex)
            return slot.role == "Background" && c.s <= 0.08 && c.b >= 0.94
        }
        let hasText = plan.slots.contains { slot in
            slot.role == "Text" && hsb(of: slot.hex).b <= 0.22
        }
        XCTAssertTrue(hasBackground, "expected a Background-role neutral light slot at size 5")
        XCTAssertTrue(hasText, "expected a Text-role neutral dark slot at size 5")
    }

    // MARK: - Roles

    func testRoleForBaseAssignsPrimarySecondary() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000", "#00FF00"], size: 6, scheme: .analogous, seed: 1)
        XCTAssertEqual(plan.roleForBase[0], "Primary")
        XCTAssertEqual(plan.roleForBase[1], "Secondary")
    }

    func testAccentRoleOnSaturatedSlot() {
        let plan = ColorHarmony.plan(baseHexes: ["#3366CC"], size: 6, scheme: .complementary, seed: 1)
        XCTAssertTrue(plan.slots.contains { $0.role == "Accent" })
    }

    // MARK: - Sizing

    func testSlotCountMatchesSizeMinusBaseCountAfterDedup() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000", "#FF0000", "#00FF00"], size: 6, scheme: .analogous, seed: 1)
        // dedup: 2 unique bases
        XCTAssertEqual(plan.slots.count, max(0, 6 - 2))
    }

    func testSizeLessThanOrEqualBaseCountProducesEmptySlots() {
        let plan = ColorHarmony.plan(baseHexes: ["#FF0000", "#00FF00", "#0000FF"], size: 2, scheme: .analogous, seed: 1)
        XCTAssertEqual(plan.slots.count, 0)
    }

    // MARK: - Jitter bounds over multiple seeds

    func testComplementaryJitterBoundsAcrossSeeds() {
        let baseHue = hue(of: "#FF0000")
        for seed in UInt64(0)..<20 {
            let plan = ColorHarmony.plan(baseHexes: ["#FF0000"], size: 2, scheme: .complementary, seed: seed)
            guard let slot = plan.slots.first else {
                XCTFail("expected a slot")
                continue
            }
            let delta = angularDelta(hue(of: slot.hex), baseHue + 180)
            XCTAssertLessThanOrEqual(delta, 8, "seed \(seed) hue out of jitter bounds")
            let c = hsb(of: slot.hex)
            XCTAssertGreaterThanOrEqual(c.s, 0.05)
            XCTAssertLessThanOrEqual(c.s, 1.0)
            XCTAssertGreaterThanOrEqual(c.b, 0.08)
            XCTAssertLessThanOrEqual(c.b, 0.97)
        }
    }
}

private extension UIColor {
    convenience init(hexForTest hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h.removeAll { $0 == "#" }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
