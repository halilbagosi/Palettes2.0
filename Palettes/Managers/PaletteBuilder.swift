//
//  PaletteBuilder.swift
//  Palettes
//
//  Builds every color a generated palette ships, deterministically, in
//  OKLCH. The language model never picks color values: it supplies a brief
//  (main hue, tone, harmony suggestion) and names. This file turns the
//  brief plus the user's own colors into the palette.
//
//  Structure follows the 60/30/10 rule: about half the palette is tones of
//  the main color(s), about a third sits on the scheme's other hue(s), one
//  saturated accent stands out, and palettes of six or more get tinted
//  neutrals. Interface modes use fixed role recipes instead.
//
//  Pure — no UIKit, no FoundationModels — so it is fully unit-testable.
//

import Foundation

/// Lightness and saturation bias read from a vibe ("moody" → dark,
/// "pastel" → light and muted).
struct PaletteTone: Equatable {
    enum Lightness: String, CaseIterable { case light, balanced, dark }
    enum Chroma: String, CaseIterable { case muted, balanced, vivid }

    var lightness: Lightness = .balanced
    var chroma: Chroma = .balanced

    static let balanced = PaletteTone()
}

struct PaletteBuildRequest {
    /// The user's colors. They ship verbatim, in order, at the front.
    var anchors: [String]
    var size: Int
    var scheme: HarmonyScheme
    var tone: PaletteTone = .balanced
    /// OKLCH hue (degrees) of the main color when there are no anchors,
    /// usually read from the vibe. nil lets the seed choose.
    var hue: Double? = nil
    var seed: UInt64
}

struct BuiltPalette: Equatable {
    enum Group: Equatable { case anchor, dominant, secondary, accent, neutral, interface }

    struct Entry: Equatable {
        let hex: String
        let role: String?
        let group: Group
    }

    /// The concrete scheme that was built (`.auto` resolved).
    let scheme: HarmonyScheme
    let entries: [Entry]

    var hexes: [String] { entries.map(\.hex) }
    /// Roles in the parallel-array form `PaletteViewModel` stores ("" = none).
    var roles: [String] { entries.map { $0.role ?? "" } }
}

/// Deterministic PRNG: the same request must always build the same palette,
/// so the builder never touches SystemRandomNumberGenerator.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

enum PaletteBuilder {

    // MARK: - Structure

    struct GroupCounts: Equatable {
        var dominant: Int
        var secondary: Int
        var accent: Int
        var neutral: Int
    }

    /// How a harmonic palette of `size` splits into groups. The user's own
    /// colors count toward `dominant`. Monochromatic has no second hue, so
    /// no secondary or accent.
    static func groupCounts(size: Int, scheme: HarmonyScheme) -> GroupCounts {
        let neutral = size >= 8 ? 2 : (size >= 6 ? 1 : 0)
        if scheme == .monochromatic {
            return GroupCounts(dominant: max(0, size - neutral), secondary: 0, accent: 0, neutral: neutral)
        }
        let accent = size >= 4 ? 1 : 0
        let rest = max(0, size - neutral - accent)
        let secondary = min(rest, max(1, Int((Double(rest) * 0.35).rounded())))
        return GroupCounts(dominant: rest - secondary, secondary: secondary, accent: accent, neutral: neutral)
    }

    /// Hue offsets (degrees) of a harmonic scheme's other hues.
    static func offsets(for scheme: HarmonyScheme) -> [Double] {
        switch scheme {
        case .complementary: return [180]
        case .splitComplementary: return [150, 210]
        case .triadic: return [120, 240]
        case .analogous: return [30, -30]
        case .monochromatic, .auto, .uiLight, .uiDark: return [0]
        }
    }

    // MARK: - Build

    static func build(_ request: PaletteBuildRequest) -> BuiltPalette {
        let anchorHexes = normalize(request.anchors)
        let anchors = anchorHexes.compactMap(OKLCH.init(hex:))
        let size = max(request.size, anchorHexes.count)
        var rng = SplitMix64(seed: request.seed)

        let scheme = request.scheme == .auto ? resolveAuto(anchors: anchors, rng: &rng) : request.scheme
        let anchorEntries = anchorHexes.indices.map { index in
            BuiltPalette.Entry(hex: anchorHexes[index], role: anchorRole(index, scheme: scheme), group: .anchor)
        }
        guard size > anchorHexes.count else {
            return BuiltPalette(scheme: scheme, entries: anchorEntries)
        }

        let hue = request.hue ?? Double(rng.next() % 360)
        let rotation = Int(rng.next() % 3)
        let main = mainColor(hue: hue, tone: request.tone)

        let generated = scheme.isUIMode
            ? interfaceEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, tone: request.tone, isDark: scheme == .uiDark)
            : harmonicEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, scheme: scheme, tone: request.tone, rotation: rotation)

        var entries = anchorEntries + generated
        // With none of the user's colors, nothing anchors "Primary" and the
        // rest in a harmonic palette. Interface palettes keep their roles:
        // the roles are what an interface palette is for.
        if anchorHexes.isEmpty && !scheme.isUIMode {
            entries = entries.map { BuiltPalette.Entry(hex: $0.hex, role: nil, group: $0.group) }
        }
        return BuiltPalette(scheme: scheme, entries: entries)
    }

    /// Normalizes to "#RRGGBB", drops unparseable and repeated hexes, keeps order.
    static func normalize(_ hexes: [String]) -> [String] {
        var result: [String] = []
        for raw in hexes {
            var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard OKLCH(hex: hex) != nil, !result.contains(hex) else { continue }
            result.append(hex)
        }
        return result
    }

    // MARK: - Auto

    /// Two or more of the user's colors already imply a harmony; otherwise
    /// Auto draws one, weighted toward the calmer schemes.
    private static func resolveAuto(anchors: [OKLCH], rng: inout SplitMix64) -> HarmonyScheme {
        let chromatic = anchors.filter { $0.C >= 0.03 }
        if chromatic.count >= 2 {
            let d = OKLCH.hueDistance(chromatic[0].h, chromatic[1].h)
            if d <= 45 { return .analogous }
            if abs(d - 180) <= 30 { return .complementary }
            if abs(d - 120) <= 25 { return .triadic }
            return .splitComplementary
        }
        if !anchors.isEmpty && chromatic.isEmpty { return .monochromatic }
        let roll = rng.nextUnit()
        if roll < 0.30 { return .analogous }
        if roll < 0.55 { return .complementary }
        if roll < 0.80 { return .splitComplementary }
        if roll < 0.90 { return .triadic }
        return .monochromatic
    }

    private static func anchorRole(_ index: Int, scheme: HarmonyScheme) -> String? {
        let roles = scheme.isUIMode ? ["Primary", "Secondary", "Accent"] : ["Primary", "Secondary"]
        return index < roles.count ? roles[index] : nil
    }

    // MARK: - Harmonic schemes

    private static func harmonicEntries(
        anchors: [OKLCH],
        placed initial: [String],
        main: OKLCH,
        size: Int,
        scheme: HarmonyScheme,
        tone: PaletteTone,
        rotation: Int
    ) -> [BuiltPalette.Entry] {
        var placed = initial
        var entries: [BuiltPalette.Entry] = []
        func place(_ candidates: [OKLCH], floors: [Double], role: String?, group: BuiltPalette.Group) -> BuiltPalette.Entry {
            let hex = pick(candidates, placed: placed, floors: floors)
            placed.append(hex)
            return BuiltPalette.Entry(hex: hex, role: role, group: group)
        }

        // Each root heads a family of tones: the user's colors, or the
        // brief's main color when there are none.
        let roots = anchors.isEmpty ? [main] : anchors
        if anchors.isEmpty {
            entries.append(place([main], floors: [0], role: nil, group: .dominant))
        }

        let counts = groupCounts(size: size, scheme: scheme)
        var slots: [BuiltPalette.Group] = Array(repeating: .dominant, count: max(0, counts.dominant - roots.count))
        if counts.secondary > 0 { slots.append(.secondary) }
        slots += Array(repeating: .accent, count: counts.accent)
        slots += Array(repeating: .secondary, count: max(0, counts.secondary - 1))
        slots += Array(repeating: .neutral, count: counts.neutral)
        // Many anchors can outnumber the dominant share; neutrals, then
        // extra secondaries, then the accent give way first.
        slots = Array(slots.prefix(size - placed.count))

        let schemeOffsets = offsets(for: scheme)
        let accentOffset = schemeOffsets.count > 1 ? schemeOffsets[1] : schemeOffsets[0]
        let neutralOrder: [Bool] = counts.neutral == 1 ? [tone.lightness != .dark] : [true, false]
        var dominantIndex = 0
        var secondaryIndex = 0
        var neutralIndex = 0

        // Neutrals are placed first: they have only a few candidates, while
        // the tone ladders have many and can step around them. Entries still
        // come out in slot order.
        let placementOrder = slots.indices.filter { slots[$0] == .neutral } + slots.indices.filter { slots[$0] != .neutral }
        var slotted = [BuiltPalette.Entry?](repeating: nil, count: slots.count)
        for position in placementOrder {
            switch slots[position] {
            case .dominant:
                // Round-robin over the roots, so two chosen colors get equal shares.
                let root = roots[dominantIndex % roots.count]
                dominantIndex += 1
                slotted[position] = place(toneCandidates(root: root, tone: tone, rotation: rotation), floors: [12, 9, 6], role: nil, group: .dominant)
            case .secondary:
                let root = roots[secondaryIndex % roots.count]
                let offset = schemeOffsets[(secondaryIndex / roots.count) % schemeOffsets.count]
                secondaryIndex += 1
                slotted[position] = place(secondaryCandidates(root: root, offset: offset, schemeOffsets: schemeOffsets, tone: tone), floors: [12, 9, 6], role: nil, group: .secondary)
            case .accent:
                slotted[position] = place(accentCandidates(root: roots[0], offset: accentOffset, tone: tone), floors: [12, 9, 6], role: "Accent", group: .accent)
            case .neutral:
                let light = neutralOrder[neutralIndex % neutralOrder.count]
                neutralIndex += 1
                slotted[position] = place(neutralCandidates(root: roots[0], light: light), floors: [12, 9, 6], role: light ? "Background" : "Text", group: .neutral)
            case .anchor, .interface:
                break
            }
        }
        entries += slotted.compactMap { $0 }
        return entries
    }

    /// Lightness rungs for tones of a root, in dark/light pairs, most useful
    /// first: a dark and a light tone come before the mid-tones, so even
    /// four colors span a real lightness range. The seed rotates the ladder
    /// by whole pairs, which varies the palette without breaking that order.
    private static let toneLadder: [Double] = [0.30, 0.86, 0.22, 0.94, 0.42, 0.76, 0.16, 0.97, 0.37, 0.68, 0.51, 0.58]
    private static let secondaryLadder: [Double] = [0.62, 0.42, 0.76, 0.32, 0.86, 0.52, 0.24, 0.92]
    private static let accentLadder: [Double] = [0.68, 0.58, 0.76, 0.50]

    private static func mainColor(hue: Double, tone: PaletteTone) -> OKLCH {
        let L: Double = tone.lightness == .light ? 0.78 : (tone.lightness == .dark ? 0.42 : 0.6)
        let C: Double = tone.chroma == .muted ? 0.07 : (tone.chroma == .vivid ? 0.19 : 0.13)
        return OKLCH(L: L, C: C, h: hue).gamutMapped()
    }

    /// Squeezes the ladder toward the light or dark end for a light or dark vibe.
    private static func remap(_ L: Double, _ lightness: PaletteTone.Lightness) -> Double {
        switch lightness {
        case .balanced: return L
        case .light: return 0.50 + (L - 0.16) * (0.975 - 0.50) / (0.97 - 0.16)
        case .dark: return 0.10 + (L - 0.16) * (0.70 - 0.10) / (0.97 - 0.16)
        }
    }

    private static func chromaFactor(_ chroma: PaletteTone.Chroma) -> Double {
        switch chroma {
        case .muted: return 0.55
        case .balanced: return 1
        case .vivid: return 1.3
        }
    }

    /// Chroma shrinks toward the ends of the lightness range, where sRGB
    /// holds little of it anyway, so a near-white stays a tint of its hue
    /// instead of being clipped into a different one.
    private static func lightnessChromaScale(_ L: Double) -> Double {
        min(1, max(0.35, 1 - 0.55 * abs(L - 0.6) / 0.4))
    }

    private static func toneCandidates(root: OKLCH, tone: PaletteTone, rotation: Int) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma)
        let rungs = toneLadder.indices.map { toneLadder[($0 + rotation * 2) % toneLadder.count] }
        // A grey has only lightness to vary, so it always gets the full
        // range; squeezing it for a light or dark vibe leaves too few steps.
        let lightness = root.C < 0.03 ? .balanced : tone.lightness
        let full = rungs.map { rung -> OKLCH in
            let L = remap(rung, lightness)
            return OKLCH(L: L, C: root.C * lightnessChromaScale(L) * factor, h: root.h)
        }
        // Long single-hue palettes run past the main rungs: half-chroma
        // tones, then a fine sweep that fills whatever gaps remain.
        let fine = stride(from: 0.14, through: 0.98, by: 0.04).map { rung -> OKLCH in
            OKLCH(L: rung, C: root.C * lightnessChromaScale(rung) * factor, h: root.h)
        }
        return full + full.map { OKLCH(L: $0.L, C: $0.C * 0.5, h: $0.h) } + fine
    }

    private static func secondaryCandidates(root: OKLCH, offset: Double, schemeOffsets: [Double], tone: PaletteTone) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma)
        let chroma = max(root.C, 0.06) * 0.9
        // The assigned hue first; the scheme's other hues only as a fallback.
        let hueOffsets = [offset] + schemeOffsets.filter { $0 != offset }
        return hueOffsets.flatMap { hueOffset in
            secondaryLadder.map { rung -> OKLCH in
                let L = remap(rung, tone.lightness)
                return OKLCH(L: L, C: chroma * lightnessChromaScale(L) * factor, h: root.h + hueOffset)
            }
        }
    }

    private static func accentCandidates(root: OKLCH, offset: Double, tone: PaletteTone) -> [OKLCH] {
        let shift: Double = tone.lightness == .dark ? -0.06 : (tone.lightness == .light ? 0.04 : 0)
        let chroma = 0.25 * (tone.chroma == .muted ? 0.6 : (tone.chroma == .vivid ? 1.15 : 1))
        return accentLadder.map { OKLCH(L: $0 + shift, C: chroma, h: root.h + offset) }
    }

    /// Near-white and near-black tinted with the root's hue — or true
    /// greys when the root is itself grey, whose hue angle means nothing.
    private static func neutralCandidates(root: OKLCH, light: Bool) -> [OKLCH] {
        let tint = root.C < 0.03 ? 0 : 1.0
        return light
            ? [0.97, 0.94, 0.91, 0.99].map { OKLCH(L: $0, C: 0.012 * tint, h: root.h) }
            : [0.21, 0.26, 0.17, 0.31].map { OKLCH(L: $0, C: 0.02 * tint, h: root.h) }
    }

    // MARK: - Interface modes

    private enum HueRule: Equatable {
        case primary
        case offset(Double)
        case fixed(Double)
    }

    private struct InterfaceRecipe {
        let role: String
        let light: (L: Double, C: Double)
        let dark: (L: Double, C: Double)
        let hue: HueRule
        let chromaFollowsTone: Bool
    }

    /// In fill order: a 4-color interface palette gets Primary, Background,
    /// Text and Accent; larger ones add surfaces, then status colors.
    private static let interfaceRecipes: [InterfaceRecipe] = [
        InterfaceRecipe(role: "Primary", light: (0.55, 0.15), dark: (0.72, 0.14), hue: .primary, chromaFollowsTone: true),
        InterfaceRecipe(role: "Background", light: (0.985, 0.006), dark: (0.18, 0.012), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Text", light: (0.24, 0.02), dark: (0.95, 0.008), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Accent", light: (0.64, 0.16), dark: (0.74, 0.14), hue: .offset(140), chromaFollowsTone: true),
        InterfaceRecipe(role: "Surface", light: (0.94, 0.01), dark: (0.25, 0.016), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Muted Text", light: (0.50, 0.02), dark: (0.70, 0.015), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Border", light: (0.86, 0.015), dark: (0.35, 0.02), hue: .primary, chromaFollowsTone: false),
        InterfaceRecipe(role: "Secondary", light: (0.45, 0.10), dark: (0.66, 0.09), hue: .offset(30), chromaFollowsTone: true),
        InterfaceRecipe(role: "Primary Container", light: (0.90, 0.05), dark: (0.32, 0.06), hue: .primary, chromaFollowsTone: true),
        InterfaceRecipe(role: "Success", light: (0.62, 0.15), dark: (0.72, 0.15), hue: .fixed(150), chromaFollowsTone: false),
        InterfaceRecipe(role: "Warning", light: (0.78, 0.15), dark: (0.82, 0.14), hue: .fixed(80), chromaFollowsTone: false),
        InterfaceRecipe(role: "Error", light: (0.58, 0.19), dark: (0.68, 0.17), hue: .fixed(27), chromaFollowsTone: false),
    ]

    private static func interfaceEntries(
        anchors: [OKLCH],
        placed initial: [String],
        main: OKLCH,
        size: Int,
        tone: PaletteTone,
        isDark: Bool
    ) -> [BuiltPalette.Entry] {
        var placed = initial
        var entries: [BuiltPalette.Entry] = []
        let primary = anchors.first ?? main
        let taken = Set(anchors.indices.compactMap { anchorRole($0, scheme: .uiLight) })
        let factor = chromaFactor(tone.chroma)

        for recipe in interfaceRecipes where placed.count < size && !taken.contains(recipe.role) {
            let spec = isDark ? recipe.dark : recipe.light
            let hue: Double
            switch recipe.hue {
            case .primary: hue = primary.h
            case .offset(let degrees): hue = primary.h + degrees
            case .fixed(let degrees): hue = degrees
            }
            // A grey primary has no meaningful hue to tint the surfaces with.
            let tint = primary.C < 0.03 && recipe.hue == .primary && !recipe.chromaFollowsTone ? 0 : 1.0
            let chroma = (recipe.chromaFollowsTone ? spec.C * factor : spec.C) * tint
            // Surfaces sit close together by design, so interface colors use
            // a lower distinctness floor than harmonic ones.
            let candidates = [0, 0.03, -0.03, 0.06, -0.06].map { OKLCH(L: min(0.99, max(0.05, spec.L + $0)), C: chroma, h: hue) }
            let hex = pick(candidates, placed: placed, floors: [5, 3])
            placed.append(hex)
            entries.append(BuiltPalette.Entry(hex: hex, role: recipe.role, group: .interface))
        }
        // Only reachable with many anchors: top up with tones of the primary.
        while placed.count < size {
            let hex = pick(toneCandidates(root: primary, tone: tone, rotation: 0), placed: placed, floors: [12, 9, 6])
            placed.append(hex)
            entries.append(BuiltPalette.Entry(hex: hex, role: nil, group: .dominant))
        }
        return entries
    }

    // MARK: - Distinctness

    /// The first candidate at least `floor` (CIEDE2000) from every placed
    /// color, trying each floor in turn. If none clears even the lowest,
    /// the candidate farthest from everything placed.
    private static func pick(_ candidates: [OKLCH], placed: [String], floors: [Double]) -> String {
        let hexes = candidates.map(\.hex)
        for floor in floors {
            if let hex = hexes.first(where: { !placed.contains($0) && minDistance($0, to: placed) >= floor }) {
                return hex
            }
        }
        return hexes.max { minDistance($0, to: placed) < minDistance($1, to: placed) } ?? hexes[0]
    }

    private static func minDistance(_ hex: String, to placed: [String]) -> Double {
        placed.map { ColorNamer.perceptualDistance(hex1: hex, hex2: $0) }.min() ?? .greatestFiniteMagnitude
    }
}
