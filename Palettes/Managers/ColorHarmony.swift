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
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .complementary: return "Complementary"
        case .splitComplementary: return "Split Complementary"
        case .analogous: return "Analogous"
        case .triadic: return "Triadic"
        case .monochromatic: return "Monochromatic"
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

        // Near-neutral base → monochromatic ladder plus accent.
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

    private static func targetOffsets(for scheme: HarmonyScheme) -> [CGFloat] {
        switch scheme {
        case .complementary: return [180]
        case .splitComplementary: return [150, 210]
        case .analogous: return [-15, 15, -33, 33]
        case .triadic: return [120, 240]
        case .monochromatic: return [0]
        case .auto: return [180] // never resolved to auto directly
        }
    }

    private static let monochromaticBrightnessLadder: [CGFloat] = [0.25, 0.45, 0.65, 0.85, 0.95]

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

    // MARK: - Plan

    static func plan(baseHexes: [String], size: Int, scheme: HarmonyScheme, seed: UInt64) -> HarmonyPlan {
        let normalizedHexes = normalize(baseHexes)
        let bases = normalizedHexes.compactMap(hsb(fromHex:))
        var rng = SplitMix64(seed: seed)

        let roleForBase = roleForBases(count: normalizedHexes.count)

        let resolved: HarmonyScheme = scheme == .auto ? resolveScheme(bases: bases, size: size, rng: &rng) : scheme

        let slotCount = max(0, size - normalizedHexes.count)
        guard slotCount > 0, let base = bases.first else {
            return HarmonyPlan(resolvedScheme: resolved == .auto ? .complementary : resolved, slots: [], roleForBase: roleForBase)
        }

        let baseHueDeg = base.hue * 360
        let offsets = targetOffsets(for: resolved)
        let reserveNeutrals = resolved == .splitComplementary && slotCount >= 5 && bases.count == 1

        var slots: [HarmonySlot] = []
        var accentAssigned = false
        var backgroundAssigned = false
        var textAssigned = false

        let neutralSlotCount = reserveNeutrals ? 2 : 0
        let harmonicSlotCount = slotCount - neutralSlotCount

        for i in 0..<harmonicSlotCount {
            let lap = offsets.isEmpty ? 0 : i / offsets.count
            let offsetIndex = offsets.isEmpty ? 0 : i % offsets.count

            var hueDeg: CGFloat
            var saturation: CGFloat
            var brightness: CGFloat

            if resolved == .monochromatic {
                hueDeg = baseHueDeg
                let rungIndex = i % monochromaticBrightnessLadder.count
                let lapAdjust = CGFloat(i / monochromaticBrightnessLadder.count) * 0.15
                brightness = monochromaticBrightnessLadder[rungIndex] + lapAdjust
                saturation = base.saturation
            } else {
                let offset = offsets[offsetIndex]
                hueDeg = baseHueDeg + offset
                brightness = base.brightness + CGFloat(lap) * 0.15 * (lap % 2 == 0 ? 1 : -1)
                saturation = base.saturation
            }

            // Jitter.
            let hueJitter = CGFloat(rng.nextJitter(6))
            let satJitter = CGFloat(rng.nextJitter(0.06))
            let briJitter = CGFloat(rng.nextJitter(0.05))

            hueDeg += hueJitter
            saturation = min(1.0, max(0.05, saturation + satJitter))
            brightness = min(0.97, max(0.08, brightness + briJitter))

            let hue01 = wrapHue01(hueDeg / 360)

            var role: String? = nil
            if !accentAssigned && saturation >= 0.4 {
                role = "Accent"
                accentAssigned = true
            }

            slots.append(HarmonySlot(hue: hue01, saturation: saturation, brightness: brightness, role: role))
        }

        // Reserved neutral slots: one light (Background), one dark (Text).
        if reserveNeutrals {
            // Background: same hue, low sat, high brightness.
            do {
                let hueJitter = CGFloat(rng.nextJitter(6))
                let satJitter = CGFloat(rng.nextJitter(0.02))
                let briJitter = CGFloat(rng.nextJitter(0.02))
                let hue01 = wrapHue01((baseHueDeg + hueJitter) / 360)
                let saturation = min(0.08, max(0.02, 0.05 + satJitter))
                let brightness = min(0.97, max(0.94, 0.96 + briJitter))
                slots.append(HarmonySlot(hue: hue01, saturation: saturation, brightness: brightness, role: "Background"))
                backgroundAssigned = true
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
                textAssigned = true
            }
        }
        _ = backgroundAssigned
        _ = textAssigned

        // Near-neutral base + monochromatic → one slot becomes a saturated accent.
        if resolved == .monochromatic, base.saturation < 0.12, let accentIndex = slots.indices.first(where: { slots[$0].role == nil }) {
            let accentHue = wrapHue01(rng.nextUnit())
            let accentSaturation = min(1.0, max(0.5, 0.55 + CGFloat(rng.nextJitter(0.15))))
            let accentBrightness = min(0.9, max(0.4, 0.6 + CGFloat(rng.nextJitter(0.15))))
            slots[accentIndex] = HarmonySlot(hue: accentHue, saturation: accentSaturation, brightness: accentBrightness, role: "Accent")
        }

        return HarmonyPlan(resolvedScheme: resolved, slots: slots, roleForBase: roleForBase)
    }
}
