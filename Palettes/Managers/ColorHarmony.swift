//
//  ColorHarmony.swift
//  Palettes
//
//  Pure HSB/hex math for generating harmony-driven color plans. No SwiftUI,
//  no FoundationModels — safe to unit test without rendering.
//

import UIKit

/// A named color-harmony scheme, plus `.auto` which resolves to one of the
/// concrete schemes based on the base colors and requested size.
enum HarmonyScheme: String, CaseIterable, Identifiable {
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic, uiLight, uiDark

    var id: String { rawValue }

    var isUIMode: Bool {
        self == .uiLight || self == .uiDark
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .complementary: return "Complementary"
        case .splitComplementary: return "Split Complementary"
        case .analogous: return "Analogous"
        case .triadic: return "Triadic"
        case .monochromatic: return "Monochromatic"
        case .uiLight: return "UI Light"
        case .uiDark: return "UI Dark"
        }
    }
}

/// A single generated color slot with a suggested role.
struct HarmonySlot: Equatable {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat
    let role: String?

    var hex: String {
        let ui = UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

/// The result of planning a harmony: the resolved concrete scheme, generated
/// slots to fill out the palette, and suggested roles for the base colors.
struct HarmonyPlan: Equatable {
    let resolvedScheme: HarmonyScheme
    let slots: [HarmonySlot]
    let roleForBase: [String?]

    /// What the plan was derived from — the normalized base hexes, the seed,
    /// and how many harmonic (non-neutral) slots it already emitted. Recorded
    /// so a consumer that runs short of slots can continue *this* plan's own
    /// ladder (`ColorHarmony.extraSlots(for:count:)`) instead of inventing
    /// colors outside the harmony family. Defaulted so a plan can still be
    /// constructed by hand (tests do); such a plan simply can't be extended.
    var baseHexes: [String] = []
    var seed: UInt64 = 0
    var harmonicCount: Int = 0
}

enum ColorHarmony {

    // MARK: - SplitMix64 PRNG

    /// Deterministic PRNG seeded from a fixed value. Never use
    /// SystemRandomNumberGenerator here — determinism is required.
    struct SplitMix64: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &+ 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }

        /// Uniform double in [0, 1).
        mutating func nextUnit() -> Double {
            Double(next() >> 11) * (1.0 / 9007199254740992.0) // 2^53
        }

        /// Uniform double in [-range, range].
        mutating func nextJitter(_ range: Double) -> Double {
            (nextUnit() * 2 - 1) * range
        }
    }

    // MARK: - Base color parsing

    private struct BaseHSB {
        let hue: CGFloat        // 0..1
        let saturation: CGFloat
        let brightness: CGFloat
    }

    /// Normalizes and de-duplicates hex strings, preserving order — same
    /// convention as `PaletteGenerator.lockedEntries`.
    private static func normalize(_ hexes: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()
        for raw in hexes {
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard seen.insert(hex).inserted else { continue }
            result.append(hex)
        }
        return result
    }

    private static func hsb(fromHex hex: String) -> BaseHSB? {
        var h = hex
        h.removeAll { $0 == "#" }
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return nil }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        let ui = UIColor(red: r, green: g, blue: b, alpha: 1)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &a)
        return BaseHSB(hue: hue, saturation: sat, brightness: bri)
    }

    // MARK: - Angular helpers (degrees)

    private static func angularDelta(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        var d = abs(a - b).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    private static func wrapHue01(_ hue01: CGFloat) -> CGFloat {
        var h = hue01.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        return h
    }

    // MARK: - Auto-pick heuristics (spec §1)

    private static func resolveScheme(bases: [BaseHSB], size: Int, rng: inout SplitMix64) -> HarmonyScheme {
        guard let first = bases.first else { return .complementary }

        // Near-neutral base → monochromatic ladder. The ladder must remain
        // anchored to the chosen hue: an unrelated accent belongs to a
        // different scheme, not a monochromatic result.
        if bases.count == 1 && first.saturation < 0.12 {
            return .monochromatic
        }

        if bases.count >= 2 {
            let hueA = first.hue * 360
            let hueB = bases[1].hue * 360
            let delta = angularDelta(hueA, hueB)
            if abs(delta - 180) <= 30 {
                return .complementary
            } else if delta <= 40 {
                return .analogous
            } else {
                return .splitComplementary
            }
        }

        // Single saturated base.
        if size >= 5 {
            return .splitComplementary
        }
        // size <= 4: pick complementary or analogous from rng.
        return rng.nextUnit() < 0.5 ? .complementary : .analogous
    }

    // MARK: - Target hue offsets (degrees) per scheme

    /// Takes a resolved (never `.auto`) scheme; `plan()` always resolves
    /// `.auto` before calling this.
    private static func targetOffsets(for scheme: HarmonyScheme) -> [CGFloat] {
        switch scheme {
        case .auto, .complementary: return [180]
        case .splitComplementary: return [150, 210]
        // Tightened from the design doc's ±20/±40 so ±6° hue jitter can never
        // push a slot past the spec's 40° analogous bound.
        case .analogous: return [-15, 15, -33, 33]
        case .triadic: return [120, 240]
        case .monochromatic: return [0]
        case .uiLight, .uiDark: return [0]
        }
    }

    // MARK: - Tone ladders
    //
    // Successive slots that share a hue offset must differ by tone, not by
    // hue — otherwise they read as near-duplicates, get dropped by the
    // caller's perceptual gate, and the palette comes up short. Both ladders
    // below are indexed (rather than walked with a running RNG) so slot N is
    // reproducible on its own, which is what lets a fill continue past the
    // slots a plan originally emitted while staying in the same family.

    /// Brightness/saturation steps for repeat visits to the same hue offset.
    /// `mix < 0` scales toward black, `mix > 0` interpolates toward white, so
    /// the spread stays wide for a dark base and a light one alike.
    private static let toneLadder: [(mix: CGFloat, satScale: CGFloat)] = [
        (0.00, 1.00), (-0.42, 1.00), (0.58, 0.86), (-0.66, 0.90),
        (0.86, 0.52), (-0.22, 0.70), (0.32, 1.00), (-0.52, 0.64),
        (0.70, 0.72), (-0.12, 0.88), (0.18, 0.58), (-0.78, 0.82),
    ]

    /// Monochromatic sweeps a 2D grid instead: brightness cycles fast, the
    /// saturation scale advances once per full brightness lap. 10 × 4 = 40
    /// combinations, so even a 12-color single-hue palette has enough
    /// candidates left after the caller's perceptual gate rejects the ones
    /// that read the same as a color already placed.
    private static let monochromaticBrightnessLadder: [CGFloat] = [
        0.22, 0.42, 0.62, 0.82, 0.95, 0.14, 0.32, 0.52, 0.72, 0.88,
    ]
    private static let monochromaticSaturationScales: [CGFloat] = [1.00, 0.60, 0.84, 0.38]

    // MARK: - Role assignment

    private static func roleForBases(count: Int) -> [String?] {
        (0..<count).map { index in
            switch index {
            case 0: return "Primary"
            case 1: return "Secondary"
            default: return nil
            }
        }
    }

    // MARK: - Slot generation

    /// Builds utility colors for a UI palette. The selected colors remain
    /// locked at the front of the palette as Primary/Secondary; these slots
    /// provide the neutral surfaces and readable text colors around them.
    private static func uiSlot(index: Int, bases: [BaseHSB], isDark: Bool) -> HarmonySlot {
        let anchor = bases.first(where: { $0.saturation >= 0.08 }) ?? bases[0]
        let recipes: [(role: String, saturation: CGFloat, brightness: CGFloat)] = isDark
            ? [
                ("Background", 0.10, 0.07),
                ("Text", 0.05, 0.95),
                ("Surface", 0.14, 0.20),
                ("Border", 0.20, 0.36),
                ("Muted Text", 0.10, 0.60),
                ("Accent", 0.50, 0.72),
            ]
            : [
                ("Background", 0.06, 0.98),
                ("Text", 0.12, 0.12),
                ("Surface", 0.06, 0.90),
                ("Border", 0.16, 0.72),
                ("Muted Text", 0.10, 0.40),
                ("Accent", 0.50, 0.68),
            ]

        let recipe = recipes[index % recipes.count]
        let cycle = CGFloat(index / recipes.count)
        var hue = anchor.hue
        var saturation = recipe.saturation
        var brightness = recipe.brightness

        if recipe.role == "Accent" {
            // Cycle through selected hues for larger UI palettes so every
            // chosen color contributes beyond the locked Primary/Secondary.
            let accentBase = bases[index % bases.count]
            hue = accentBase.hue
            saturation = max(0.45, min(0.90, accentBase.saturation))
            brightness = isDark
                ? max(0.55, min(0.82, accentBase.brightness + 0.15))
                : max(0.52, min(0.82, accentBase.brightness))
        }

        let cycleBrightnessShift = isDark ? cycle * 0.05 : -cycle * 0.05
        saturation = min(0.92, max(0.03, saturation + cycle * 0.015))
        brightness = min(0.97, max(0.08, brightness + cycleBrightnessShift))

        return HarmonySlot(
            hue: wrapHue01(hue),
            saturation: saturation,
            brightness: brightness,
            role: recipe.role
        )
    }

    /// Builds the harmonic slot at `index` for an already-resolved scheme.
    ///
    /// Deterministic in `(seed, index)` alone — deliberately *not* drawn from
    /// one running RNG stream — so slot N is identical whether it was emitted
    /// by `plan()` or requested later by `extraSlots(for:count:)`. That's what
    /// keeps a top-up in the same harmony family: the caller never has to
    /// invent a hue of its own to reach the requested palette size.
    private static func harmonicSlot(index: Int, bases: [BaseHSB], scheme: HarmonyScheme, seed: UInt64) -> HarmonySlot {
        // Mixed (not offset) into the seed: SplitMix64 advances its state by a
        // fixed constant, so seeding successive indices by simple addition
        // would hand index N the same numbers index N-1 already used, one
        // draw out of step.
        precondition(!bases.isEmpty, "A harmonic slot requires at least one base color")

        if scheme == .uiLight || scheme == .uiDark {
            return uiSlot(index: index, bases: bases, isDark: scheme == .uiDark)
        }

        // Walk bases round-robin, so every selected color contributes its
        // own harmony family. `toneIndex` advances only after every base got
        // a turn: with two selected colors and six generated slots this is
        // A0, B0, A1, B1, A2, B2 — equal quantities without the first color
        // silently consuming the entire palette.
        let baseIndex = index % bases.count
        let toneIndex = index / bases.count
        let base = bases[baseIndex]
        var rng = SplitMix64(seed: seed ^ (UInt64(bitPattern: Int64(index)) &+ 1) &* 0xD1B5_4A32_D192_ED03)
        let baseHueDeg = base.hue * 360

        var hueDeg: CGFloat
        var saturation: CGFloat
        var brightness: CGFloat

        if scheme == .monochromatic {
            let ladder = monochromaticBrightnessLadder
            let scales = monochromaticSaturationScales
            hueDeg = baseHueDeg
            brightness = ladder[toneIndex % ladder.count]
            saturation = base.saturation * scales[(toneIndex / ladder.count) % scales.count]
        } else {
            let offsets = targetOffsets(for: scheme)
            let offset = offsets.isEmpty ? 0 : offsets[toneIndex % offsets.count]
            let lap = offsets.isEmpty ? toneIndex : toneIndex / offsets.count
            let tone = toneLadder[lap % toneLadder.count]
            // Past a full trip through the tone ladder, keep desaturating so
            // a long palette (size 12 on a single-offset scheme) still finds
            // fresh, in-family tones instead of repeating itself.
            let lapWrapScale: CGFloat = [1.00, 0.66, 0.44][(lap / toneLadder.count) % 3]
            hueDeg = baseHueDeg + offset
            brightness = tone.mix < 0
                ? base.brightness * (1 + tone.mix)
                : base.brightness + (0.97 - base.brightness) * tone.mix
            saturation = base.saturation * tone.satScale * lapWrapScale
        }

        hueDeg += CGFloat(rng.nextJitter(6))
        saturation = min(1.0, max(0.05, saturation + CGFloat(rng.nextJitter(0.06))))
        brightness = min(0.97, max(0.08, brightness + CGFloat(rng.nextJitter(0.05))))

        return HarmonySlot(hue: wrapHue01(hueDeg / 360), saturation: saturation, brightness: brightness, role: nil)
    }

    /// Continues a plan's own ladder past the slots it already produced.
    ///
    /// Use this — never an ad-hoc hue rotation — when a palette comes up
    /// short of its requested size: every returned slot sits on the same
    /// scheme's hue offsets as the plan itself, so topping up can't turn a
    /// monochromatic palette polychromatic. Returns `[]` for a hand-built
    /// plan that carries no base hexes, since there is nothing to extend.
    /// Slots are returned role-less: roles belong to the deliberate plan.
    static func extraSlots(for plan: HarmonyPlan, count: Int) -> [HarmonySlot] {
        let bases = normalize(plan.baseHexes).compactMap(hsb(fromHex:))
        guard count > 0, !bases.isEmpty else { return [] }
        return (0..<count).map { offset in
            let slot = harmonicSlot(index: plan.harmonicCount + offset, bases: bases, scheme: plan.resolvedScheme, seed: plan.seed)
            return HarmonySlot(hue: slot.hue, saturation: slot.saturation, brightness: slot.brightness, role: nil)
        }
    }

    // MARK: - Plan

    static func plan(baseHexes: [String], size: Int, scheme: HarmonyScheme, seed: UInt64) -> HarmonyPlan {
        let normalizedHexes = normalize(baseHexes)
        let bases = normalizedHexes.compactMap(hsb(fromHex:))
        var rng = SplitMix64(seed: seed)

        let roleForBase = roleForBases(count: normalizedHexes.count)

        let resolved: HarmonyScheme = scheme == .auto ? resolveScheme(bases: bases, size: size, rng: &rng) : scheme

        let slotCount = max(0, size - normalizedHexes.count)
        guard slotCount > 0, !bases.isEmpty else {
            return HarmonyPlan(
                resolvedScheme: resolved == .auto ? .complementary : resolved,
                slots: [],
                roleForBase: roleForBase,
                baseHexes: normalizedHexes,
                seed: seed,
                harmonicCount: 0
            )
        }

        // Gate on the raw requested `size` (matching resolveScheme's own
        // `size >= 5` check), not `slotCount`, so a single saturated base at
        // size 5 (slotCount 4) still reserves its Background/Text neutrals.
        let reserveNeutrals = resolved == .splitComplementary && size >= 5 && bases.count == 1 && slotCount >= 2

        var slots: [HarmonySlot] = []
        var accentAssigned = false

        let neutralSlotCount = reserveNeutrals ? 2 : 0
        let harmonicSlotCount = slotCount - neutralSlotCount

        for i in 0..<harmonicSlotCount {
            var slot = harmonicSlot(index: i, bases: bases, scheme: resolved, seed: seed)
            if !accentAssigned && slot.saturation >= 0.4 {
                slot = HarmonySlot(hue: slot.hue, saturation: slot.saturation, brightness: slot.brightness, role: "Accent")
                accentAssigned = true
            }
            slots.append(slot)
        }

        // Reserved neutral slots: one light (Background), one dark (Text).
        if reserveNeutrals {
            // `reserveNeutrals` is deliberately single-base only, so these
            // utility colors cannot skew the selected-base distribution.
            let baseHueDeg = bases[0].hue * 360
            // Background: same hue, low sat, high brightness.
            do {
                let hueJitter = CGFloat(rng.nextJitter(6))
                let satJitter = CGFloat(rng.nextJitter(0.02))
                let briJitter = CGFloat(rng.nextJitter(0.02))
                let hue01 = wrapHue01((baseHueDeg + hueJitter) / 360)
                let saturation = min(0.08, max(0.02, 0.05 + satJitter))
                let brightness = min(0.97, max(0.94, 0.96 + briJitter))
                slots.append(HarmonySlot(hue: hue01, saturation: saturation, brightness: brightness, role: "Background"))
            }
            // Text: same hue, low-ish sat, low brightness.
            do {
                let hueJitter = CGFloat(rng.nextJitter(6))
                let satJitter = CGFloat(rng.nextJitter(0.04))
                let briJitter = CGFloat(rng.nextJitter(0.02))
                let hue01 = wrapHue01((baseHueDeg + hueJitter) / 360)
                let saturation = min(0.20, max(0.05, 0.12 + satJitter))
                let brightness = min(0.22, max(0.08, 0.15 + briJitter))
                slots.append(HarmonySlot(hue: hue01, saturation: saturation, brightness: brightness, role: "Text"))
            }
        }

        return HarmonyPlan(
            resolvedScheme: resolved,
            slots: slots,
            roleForBase: roleForBase,
            baseHexes: normalizedHexes,
            seed: seed,
            harmonicCount: harmonicSlotCount
        )
    }
}
