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

    /// This tone where it says something, `fallback` where it is balanced:
    /// a vibe's own tone wins over a style's, channel by channel.
    func filling(from fallback: PaletteTone) -> PaletteTone {
        PaletteTone(lightness: lightness == .balanced ? fallback.lightness : lightness,
                    chroma: chroma == .balanced ? fallback.chroma : chroma)
    }
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
    /// A second hue the vibe names, for the secondary and accent colors of a
    /// palette with none of the user's colors. Ignored by monochromatic and
    /// interface palettes.
    var secondaryHue: Double? = nil
    var seed: UInt64
    /// The design style to follow (see `PaletteStyle`). nil builds exactly
    /// as the builder did before styles existed.
    var style: PaletteStyle? = nil
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

    /// Hue (degrees) of the first chromatic generated color: the main color
    /// the builder chose. nil when every generated color is a grey.
    var mainHue: Double? {
        entries.lazy
            .filter { $0.group != .anchor && $0.group != .neutral }
            .compactMap { OKLCH(hex: $0.hex) }
            .first { $0.C >= 0.03 }?.h
    }
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

    /// What the seed varies, so generating again with the same colors, vibe
    /// and mode gives a new palette that still follows that mode. Harmonic
    /// schemes keep their hues exactly (a scheme is its hues); the seed moves
    /// lightness, chroma and which hue leads. Interface modes keep each
    /// role's job (a near-white background, a readable text) and vary the
    /// accent's relationship, the surfaces' tint and the accent colors' tone.
    struct Variation {
        /// Tone-ladder rotation, in whole dark/light pairs (0..<3: later
        /// pairs sit too close together to lead a small palette).
        var rotation = 0
        /// Chroma multiplier for generated tones.
        var chroma = 1.0
        /// The scheme's second hue leads instead of its first.
        var swapsOffsets = false
        /// Where the accent ladder starts.
        var accentStart = 0
        // Interface modes
        var accentOffset = 140.0
        var secondaryOffset = 30.0
        /// Tint strength of backgrounds, surfaces, borders and text.
        var neutralTint = 1.0
        /// Neutrals take the accent's hue instead of the primary's.
        var neutralsFollowAccent = false
        /// Lightness nudge for the colored roles (Primary, Accent, Secondary).
        var colorLightness = 0.0
        // Styled builds (see `narrow`)
        /// Degrees added to a style's relative Accent and Secondary hues.
        var accentJitter = 0.0
        var secondaryJitter = 0.0

        static let fixed = Variation()

        init() {}

        init(rng: inout SplitMix64) {
            rotation = Int(rng.next() % 3)
            chroma = 0.9 + 0.25 * rng.nextUnit()
            swapsOffsets = rng.next() % 2 == 0
            // 0.68 or 0.76 first: a darker first accent can flatten a small palette.
            accentStart = rng.next() % 2 == 0 ? 0 : 2
            let accentOffsets: [Double] = [140, 180, 150, -150, 120, -120, 160, -160]
            accentOffset = accentOffsets[Int(rng.next() % UInt64(accentOffsets.count))]
            secondaryOffset = (25 + 20 * rng.nextUnit()) * (rng.next() % 2 == 0 ? 1 : -1)
            let tints: [Double] = [0.3, 0.8, 1.4, 2.2]
            neutralTint = tints[Int(rng.next() % UInt64(tints.count))]
            neutralsFollowAccent = rng.nextUnit() < 0.25
            colorLightness = -0.05 + 0.1 * rng.nextUnit()
        }

        /// A style sets the character, so the seed only moves it a little.
        /// Draws after `init(rng:)`'s draws, so unstyled builds are unchanged.
        mutating func narrow(rng: inout SplitMix64) {
            accentJitter = -15 + 30 * rng.nextUnit()
            secondaryJitter = -10 + 20 * rng.nextUnit()
            chroma = 0.95 + 0.1 * rng.nextUnit()
            neutralTint = 0.8 + 0.4 * rng.nextUnit()
            colorLightness = -0.03 + 0.06 * rng.nextUnit()
            neutralsFollowAccent = false
        }
    }

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
        let anchors = anchorHexes.compactMap { OKLCH(hex: $0) }
        let size = max(request.size, anchorHexes.count)
        var rng = SplitMix64(seed: request.seed)

        // A vibe that names two colors ("ocean sunset") is not a one-hue palette.
        let secondaryHue = anchors.isEmpty ? request.secondaryHue : nil
        let treatment = request.scheme == .auto ? request.style?.treatment : nil
        var scheme: HarmonyScheme
        if let treatment {
            // A style of one harmony is that harmony, whatever the user's
            // colors imply. One with several follows the user's colors, and
            // otherwise the seed picks among them.
            scheme = treatment.harmonies.count == 1
                ? treatment.harmonies[0]
                : impliedHarmony(of: anchors) ?? treatment.harmonies[Int(rng.next() % UInt64(treatment.harmonies.count))]
        } else {
            scheme = request.scheme == .auto ? resolveAuto(anchors: anchors, rng: &rng) : request.scheme
            if request.scheme == .auto, secondaryHue != nil, scheme == .monochromatic { scheme = .complementary }
        }
        let anchorEntries = anchorHexes.indices.map { index in
            BuiltPalette.Entry(hex: anchorHexes[index], role: anchorRole(index, scheme: scheme), group: .anchor)
        }
        guard size > anchorHexes.count else {
            return BuiltPalette(scheme: scheme, entries: anchorEntries)
        }

        let tone = treatment?.tone.map { request.tone.filling(from: $0) } ?? request.tone
        let freeHue = request.hue ?? Double(rng.next() % 360)
        var variation = Variation(rng: &rng)
        if request.style != nil { variation.narrow(rng: &rng) }
        let main = mainColor(hue: freeHue, tone: tone)

        let generated = scheme.isUIMode
            ? interfaceEntries(anchors: anchors, placed: anchorHexes, main: main, size: size, tone: tone, isDark: scheme == .uiDark, variation: variation, style: request.style, freeHue: freeHue)
            : harmonicEntries(anchors: anchors, placed: anchorHexes, main: main, secondaryHue: scheme == .monochromatic ? nil : secondaryHue, size: size, scheme: scheme, tone: tone, variation: variation, treatment: treatment, freeHue: freeHue)

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

    /// The harmony the user's colors already imply: two or more chromatic
    /// colors by their hue distance, all-grey colors as monochromatic. nil
    /// when the colors leave it open.
    static func impliedHarmony(of anchors: [OKLCH]) -> HarmonyScheme? {
        let chromatic = anchors.filter { $0.C >= 0.03 }
        if chromatic.count >= 2 {
            let d = OKLCH.hueDistance(chromatic[0].h, chromatic[1].h)
            if d <= 45 { return .analogous }
            if abs(d - 180) <= 30 { return .complementary }
            if abs(d - 120) <= 25 { return .triadic }
            return .splitComplementary
        }
        if !anchors.isEmpty && chromatic.isEmpty { return .monochromatic }
        return nil
    }

    /// Two or more of the user's colors already imply a harmony; otherwise
    /// Auto draws one, weighted toward the calmer schemes.
    private static func resolveAuto(anchors: [OKLCH], rng: inout SplitMix64) -> HarmonyScheme {
        if let implied = impliedHarmony(of: anchors) { return implied }
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
        secondaryHue: Double? = nil,
        size: Int,
        scheme: HarmonyScheme,
        tone: PaletteTone,
        variation: Variation,
        treatment: PaletteStyle.Treatment? = nil,
        freeHue: Double = 0
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
        let pull = treatment?.earthPull ?? 0
        let band = treatment?.lightnessBand
        /// Earth pull, then the lightness band: for families whose hue is an
        /// offset from an unpulled root, so every generated hue moves toward earth once.
        func shaped(_ candidates: [OKLCH]) -> [OKLCH] { spreading(candidates.map { banded(pulled($0, by: pull), into: band) }, band: band) }
        let baseRoots = anchors.isEmpty ? [main] : anchors
        // The user's colors keep their own hue: only the hues generated from
        // them (secondary, accent) are pulled. The brief's main color, which
        // is generated too, is pulled as well.
        let roots = anchors.isEmpty ? baseRoots.map { pulled($0, by: pull) } : baseRoots
        if anchors.isEmpty {
            entries.append(place(shaped([main]), floors: [0], role: nil, group: .dominant))
        }

        var counts = groupCounts(size: size, scheme: scheme)
        if treatment?.dropsSecondary == true {
            counts.dominant += counts.secondary
            counts.secondary = 0
        }
        if treatment?.addsAccent == true, counts.accent == 0, size >= 4, counts.dominant > 1 {
            counts.accent = 1
            counts.dominant -= 1
        }
        let chroma = variation.chroma * (treatment?.chromaScale ?? 1)
        var slots: [BuiltPalette.Group] = Array(repeating: .dominant, count: max(0, counts.dominant - roots.count))
        if counts.secondary > 0 { slots.append(.secondary) }
        slots += Array(repeating: .accent, count: counts.accent)
        slots += Array(repeating: .secondary, count: max(0, counts.secondary - 1))
        slots += Array(repeating: .neutral, count: counts.neutral)
        // Many anchors can outnumber the dominant share; neutrals, then
        // extra secondaries, then the accent give way first.
        slots = Array(slots.prefix(size - placed.count))

        // The vibe's own second hue replaces the scheme's rotation: the
        // secondary tones sit on it, the accent a little past it.
        var schemeOffsets = offsets(for: scheme)
        if let secondaryHue {
            let delta = (secondaryHue - baseRoots[0].h).truncatingRemainder(dividingBy: 360)
            schemeOffsets = [delta, delta + 20]
        }
        if variation.swapsOffsets, secondaryHue == nil, schemeOffsets.count > 1 { schemeOffsets.swapAt(0, 1) }
        let accentOffset = treatment?.accentOffset ?? (schemeOffsets.count > 1 ? schemeOffsets[1] : schemeOffsets[0])
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
                // A grey has only lightness to vary: squeezed into a band it
                // could not hold more than a few distinct tones.
                let rootBand = root.C < 0.03 ? nil : band
                slotted[position] = place(spreading(toneCandidates(root: root, tone: tone, rotation: variation.rotation, chroma: chroma).map { banded($0, into: rootBand) }, band: rootBand), floors: [12, 9, 6], role: nil, group: .dominant)
            case .secondary:
                let root = baseRoots[secondaryIndex % baseRoots.count]
                let offset = schemeOffsets[(secondaryIndex / roots.count) % schemeOffsets.count]
                secondaryIndex += 1
                slotted[position] = place(shaped(secondaryCandidates(root: root, offset: offset, schemeOffsets: schemeOffsets, tone: tone, chroma: chroma)), floors: [12, 9, 6], role: nil, group: .secondary)
            case .accent:
                // A grey root's hue angle means nothing: a treatment's accent
                // counts from the brief's or seed's hue instead.
                let accentRoot = treatment != nil && baseRoots[0].C < 0.03
                    ? OKLCH(L: baseRoots[0].L, C: baseRoots[0].C, h: freeHue) : baseRoots[0]
                // A pop accent is vivid unless the vibe asked for muted.
                let accentTone = treatment?.vividAccent == true && tone.chroma != .muted
                    ? PaletteTone(lightness: tone.lightness, chroma: .vivid) : tone
                slotted[position] = place(shaped(accentCandidates(root: accentRoot, offset: accentOffset, tone: accentTone, start: variation.accentStart, chromaScale: treatment?.chromaScale ?? 1)), floors: [12, 9, 6], role: "Accent", group: .accent)
            case .neutral:
                let light = neutralOrder[neutralIndex % neutralOrder.count]
                neutralIndex += 1
                slotted[position] = place(neutralCandidates(root: roots[0], light: light, aboveBand: band != nil), floors: [12, 9, 6], role: light ? "Background" : "Text", group: .neutral)
            case .anchor, .interface:
                break
            }
        }
        entries += slotted.compactMap { $0 }
        return entries
    }

    /// `color` with its lightness mapped from the ladders' span (0.10...0.98)
    /// into `band`, keeping the rungs' order and spacing. nil leaves it as is.
    private static func banded(_ color: OKLCH, into band: ClosedRange<Double>?) -> OKLCH {
        guard let band else { return color }
        let t = min(1, max(0, (color.L - 0.10) / 0.88))
        return OKLCH(L: band.lowerBound + t * (band.upperBound - band.lowerBound), C: color.C, h: color.h)
    }

    /// A banded family's candidates, then the same lightnesses a few degrees
    /// around the hue: squeezed into a band, one hue holds too few tones that
    /// stay apart, so `pick` needs neighbors to step to. No band, no change.
    private static func spreading(_ candidates: [OKLCH], band: ClosedRange<Double>?) -> [OKLCH] {
        guard band != nil else { return candidates }
        return candidates + [20.0, -20, 40, -40, 60, -60].flatMap { shift in
            candidates.map { OKLCH(L: $0.L, C: $0.C, h: OKLCH.wrap($0.h + shift)) }
        }
    }

    /// `color` with its hue moved `fraction` of the shorter way toward 60°
    /// (earth tones). Greys have no hue to move.
    private static func pulled(_ color: OKLCH, by fraction: Double) -> OKLCH {
        guard fraction > 0, color.C >= 0.03 else { return color }
        var delta = (60 - color.h).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return OKLCH(L: color.L, C: color.C, h: OKLCH.wrap(color.h + delta * fraction))
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

    private static func toneCandidates(root: OKLCH, tone: PaletteTone, rotation: Int, chroma: Double = 1) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma) * chroma
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

    private static func secondaryCandidates(root: OKLCH, offset: Double, schemeOffsets: [Double], tone: PaletteTone, chroma variationChroma: Double = 1) -> [OKLCH] {
        let factor = chromaFactor(tone.chroma) * variationChroma
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

    private static func accentCandidates(root: OKLCH, offset: Double, tone: PaletteTone, start: Int = 0, chromaScale: Double = 1) -> [OKLCH] {
        let shift: Double = tone.lightness == .dark ? -0.06 : (tone.lightness == .light ? 0.04 : 0)
        let chroma = 0.25 * (tone.chroma == .muted ? 0.6 : (tone.chroma == .vivid ? 1.15 : 1)) * chromaScale
        let ladder = accentLadder.indices.map { accentLadder[($0 + start) % accentLadder.count] }
        return ladder.map { OKLCH(L: $0 + shift, C: chroma, h: root.h + offset) }
    }

    /// Near-white and near-black tinted with the root's hue — or true
    /// greys when the root is itself grey, whose hue angle means nothing.
    private static func neutralCandidates(root: OKLCH, light: Bool, aboveBand: Bool = false) -> [OKLCH] {
        let tint = root.C < 0.03 ? 0 : 1.0
        // A lightness band leaves the light neutral above it, clear of the toned colors.
        let lights = aboveBand ? [0.97, 0.985, 0.96, 0.99] : [0.97, 0.94, 0.91, 0.99]
        return light
            ? lights.map { OKLCH(L: $0, C: 0.012 * tint, h: root.h) }
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
        isDark: Bool,
        variation: Variation = .fixed,
        style: PaletteStyle? = nil,
        freeHue: Double = 0
    ) -> [BuiltPalette.Entry] {
        var placed = initial
        var entries: [BuiltPalette.Entry] = []
        let primary = anchors.first ?? main
        let taken = Set(anchors.indices.compactMap { anchorRole($0, scheme: .uiLight) })
        let factor = chromaFactor(tone.chroma)

        // With few colors to generate (a small palette, or several of the
        // user's colors taking Primary, Secondary and Accent) the leftovers. Background and Text are
        // near-mirror images in Light and Dark (a near-white and a
        // near-black either way), so those few would build the same set of
        // swatches in both modes: the mode's own surfaces come first instead.
        var recipes = interfaceRecipes
        if size - anchors.count < 6 {
            // Surfaces, then the accent, then text: Light leans light, Dark leans dark.
            let lead = ["Primary", "Background", "Surface", "Accent", "Text"]
            recipes = lead.compactMap { role in interfaceRecipes.first { $0.role == role } }
                + interfaceRecipes.filter { !lead.contains($0.role) }
        }

        for recipe in recipes where placed.count < size && !taken.contains(recipe.role) {
            if let spec = style?.interfaceRoles?[recipe.role] {
                let candidates = styledCandidates(spec, role: recipe.role, colored: recipe.chromaFollowsTone,
                                                  primary: primary, freeHue: freeHue, factor: factor, variation: variation)
                let hex = pick(candidates, placed: placed, floors: [5, 3])
                placed.append(hex)
                entries.append(BuiltPalette.Entry(hex: hex, role: recipe.role, group: .interface))
                continue
            }
            let spec = isDark ? recipe.dark : recipe.light
            let isNeutral = recipe.hue == .primary && !recipe.chromaFollowsTone
            let accentHue = primary.h + variation.accentOffset
            let hue: Double
            switch recipe.hue {
            case .primary: hue = isNeutral && variation.neutralsFollowAccent ? accentHue : primary.h
            case .offset(let degrees):
                // The seed picks the accent's and secondary's relationship.
                hue = primary.h + (recipe.role == "Accent" ? variation.accentOffset
                    : recipe.role == "Secondary" ? variation.secondaryOffset : degrees)
            case .fixed(let degrees): hue = degrees
            }
            // A grey primary has no meaningful hue to tint the surfaces with.
            let tint = primary.C < 0.03 && isNeutral ? 0 : (isNeutral ? variation.neutralTint : 1.0)
            let chroma = (recipe.chromaFollowsTone ? spec.C * factor * variation.chroma : spec.C) * tint
            // Colored roles move a little in lightness; neutrals keep theirs,
            // so a background stays a background and text stays readable.
            let L = spec.L + (recipe.chromaFollowsTone ? variation.colorLightness : 0)
            // Surfaces sit close together by design, so interface colors use
            // a lower distinctness floor than harmonic ones.
            let candidates = [0, 0.03, -0.03, 0.06, -0.06].map { OKLCH(L: min(0.99, max(0.05, L + $0)), C: chroma, h: hue) }
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

    /// Candidates for one role of an interface style. Colored roles follow
    /// the tone and move a little with the seed; neutrals keep their place,
    /// so a background stays a background and text stays readable. A grey
    /// primary greys the relative neutrals, and its colored roles count
    /// from the brief's or seed's hue instead of the grey's meaningless angle.
    private static func styledCandidates(
        _ spec: PaletteStyle.RoleSpec,
        role: String,
        colored: Bool,
        primary: OKLCH,
        freeHue: Double,
        factor: Double,
        variation: Variation
    ) -> [OKLCH] {
        let isGrey = primary.C < 0.03
        var chroma = spec.C
        let hue: Double
        switch spec.hue {
        case .fixed(let degrees):
            hue = degrees
        case .relative(let degrees):
            let jitter = role == "Accent" ? variation.accentJitter : (role == "Secondary" ? variation.secondaryJitter : 0)
            hue = (isGrey && colored ? freeHue : primary.h) + degrees + jitter
            if !colored { chroma *= isGrey ? 0 : variation.neutralTint }
        }
        if colored { chroma *= factor * variation.chroma }
        let L = spec.L + (colored ? variation.colorLightness : 0)
        // A style may ask for exact black or white, so only 0...1 bounds it.
        return [0, 0.03, -0.03, 0.06, -0.06].map {
            OKLCH(L: min(1, max(0, L + $0)), C: chroma, h: OKLCH.wrap(hue))
        }
    }

    // MARK: - Distinctness

    /// The first candidate at least `floor` (CIEDE2000) from every placed
    /// color, trying each floor in turn. If none clears even the lowest,
    /// the not-yet-placed candidate farthest from everything placed (an
    /// already-placed hex only if every candidate is placed).
    private static func pick(_ candidates: [OKLCH], placed: [String], floors: [Double]) -> String {
        let hexes = candidates.map(\.hex)
        for floor in floors {
            if let hex = hexes.first(where: { !placed.contains($0) && minDistance($0, to: placed) >= floor }) {
                return hex
            }
        }
        let fresh = hexes.filter { !placed.contains($0) }
        let pool = fresh.isEmpty ? hexes : fresh
        // Candidates are never empty, so `max` always finds one.
        return pool.max { minDistance($0, to: placed) < minDistance($1, to: placed) }!
    }

    private static func minDistance(_ hex: String, to placed: [String]) -> Double {
        placed.map { ColorNamer.perceptualDistance(hex1: hex, hex2: $0) }.min() ?? .greatestFiniteMagnitude
    }
}
