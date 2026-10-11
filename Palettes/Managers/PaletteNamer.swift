//
//  PaletteNamer.swift
//  Palettes
//
//  Names a whole palette. The on-device model's suggestion is used when it is
//  actually specific and unused; otherwise a title is derived from the
//  palette's own colors so names stay diverse, descriptive, and available
//  offline (and on the Simulator, where Apple Intelligence can't run).
//
//  Deliberately ungated (no `@available`) and free of FoundationModels so it
//  is unit-testable and usable from every code path.
//

import Foundation
import UIKit

enum PaletteNamer {

    // MARK: - Public API

    /// Resolves the final palette title: keeps `aiName` when it's specific, names
    /// only colors the palette has, and isn't already taken; otherwise
    /// synthesizes a descriptive one from the palette's colors.
    ///
    /// - Parameters:
    ///   - aiName: the model's suggestion, if any.
    ///   - hexes: the palette's colors, as "#RRGGBB".
    ///   - existingNames: names already in the user's library (any casing);
    ///     the result is guaranteed not to match one of these.
    static func resolvedName(aiName: String?, hexes: [String], existingNames: [String]) -> String {
        let taken = Set(existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        if let candidate = aiName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !candidate.isEmpty,
           !isGeneric(candidate),
           !usesClichedTitleLanguage(candidate),
           ColorVocabulary.isPlausibleTitle(candidate, forHexes: hexes),
           !taken.contains(candidate.lowercased()) {
            return candidate
        }
        return descriptiveName(forHexes: hexes, existingNames: existingNames)
    }

    /// Builds a title from what the palette actually looks like: a character
    /// word derived from its temperature / saturation / lightness, plus the
    /// color family of its most characteristic color (e.g. "Muted Terracotta",
    /// "Deep Ocean Dusk"). Deterministic for a given palette, and never equal
    /// to any name in `existingNames`.
    static func descriptiveName(forHexes hexes: [String], existingNames: [String]) -> String {
        let taken = Set(existingNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let traits = traits(forHexes: hexes)

        // Rotate vocabulary and title structure with the palette's stable
        // seed. Each word still describes the actual colors, but palettes with
        // similar traits don't all begin with the same adjective or closer.
        var candidates: [String] = []
        let character = rotated(characterWords(for: traits), by: traits.seed)
        let family = familyWord(for: traits)
        let closers = rotated(closerWords(for: traits), by: traits.seed / 7)

        switch traits.seed % 3 {
        case 0:
            for word in character {
                candidates.append("\(word) \(family)")
            }
            for closer in closers {
                candidates.append("\(family) \(closer)")
                for word in character.prefix(2) {
                    candidates.append("\(word) \(family) \(closer)")
                }
            }
        case 1:
            for closer in closers {
                candidates.append("\(family) \(closer)")
            }
            for word in character {
                candidates.append("\(word) \(family)")
                if let closer = closers.first {
                    candidates.append("\(word) \(family) \(closer)")
                }
            }
        default:
            for word in character {
                for closer in closers.prefix(2) {
                    candidates.append("\(word) \(family) \(closer)")
                }
                candidates.append("\(word) \(family)")
            }
            for closer in closers {
                candidates.append("\(family) \(closer)")
            }
        }

        for candidate in candidates where !taken.contains(candidate.lowercased()) {
            return candidate
        }
        // Everything collided (a library already holding these titles): append
        // a deterministic, palette-derived distinguisher rather than a number.
        let seedWord = seedWords[positiveModulo(traits.seed, seedWords.count)]
        let fallback = "\(seedWord) \(family)"
        if !taken.contains(fallback.lowercased()) { return fallback }
        return "\(character.first ?? "Custom") \(seedWord) \(family)"
    }

    // MARK: - Traits

    private struct Traits {
        /// Hue of the palette's first clearly colored swatch, never an
        /// average (averaging opposing hues names a family that isn't in
        /// the palette at all). Generated palettes list the user's colors
        /// and the main color's family first, so this is the main color,
        /// not the loudest accent.
        var hue: Double
        /// Brightness of that same characteristic color, so the family word
        /// ("Terracotta" vs "Ember") describes a real color, not the mean.
        var familyBrightness: Double
        var saturation: Double   // 0..1 mean
        var brightness: Double   // 0..1 mean
        var spread: Double       // brightness range across the palette
        var hueSpread: Double    // how far apart the hues are (0..0.5)
        var isNeutral: Bool      // essentially unsaturated
        var count: Int
        var seed: Int
    }

    private static func traits(forHexes hexes: [String]) -> Traits {
        var chromatic: [(h: Double, s: Double, b: Double)] = []
        var sats: [Double] = []
        var brights: [Double] = []

        for hex in hexes {
            guard let hsb = hsb(fromHex: hex) else { continue }
            sats.append(hsb.s)
            brights.append(hsb.b)
            // Only colors with real chroma can name a family; grays can't.
            if hsb.s > 0.12 { chromatic.append(hsb) }
        }

        guard !brights.isEmpty else {
            return Traits(hue: 0, familyBrightness: 0.5, saturation: 0, brightness: 0.5,
                          spread: 0, hueSpread: 0, isNeutral: true, count: 0,
                          seed: deterministicSeed(hexes))
        }

        // The palette's "signature" color: its first clearly colored swatch.
        // Its hue names the family, so the title always points at a color
        // that is genuinely present — and at the main one.
        let signature = chromatic.first

        // How spread out the hues are — a wide spread means "no single family
        // describes this", which the character words can acknowledge.
        var hueSpread = 0.0
        if chromatic.count > 1 {
            let hues = chromatic.map { $0.h }.sorted()
            var maxGap = 0.0
            for i in hues.indices {
                let next = i + 1 < hues.count ? hues[i + 1] : hues[0] + 1
                maxGap = max(maxGap, next - hues[i])
            }
            hueSpread = max(0, 1 - maxGap)   // 0 = tightly clustered
        }

        let meanSat = sats.reduce(0, +) / Double(sats.count)
        let meanBright = brights.reduce(0, +) / Double(brights.count)

        return Traits(
            hue: signature?.h ?? 0,
            familyBrightness: signature?.b ?? meanBright,
            saturation: meanSat,
            brightness: meanBright,
            spread: (brights.max() ?? 0) - (brights.min() ?? 0),
            hueSpread: hueSpread,
            isNeutral: chromatic.isEmpty || meanSat < 0.12,
            count: brights.count,
            seed: deterministicSeed(hexes)
        )
    }

    // MARK: - Vocabulary

    /// Character words ordered by how well they fit the palette, so the first
    /// available one is also the most apt.
    private static func characterWords(for t: Traits) -> [String] {
        var words: [String] = []
        if t.isNeutral {
            words += t.brightness > 0.7
                ? ["Pale", "Frosted", "Porcelain", "Soft", "Quiet"]
                : ["Slate", "Graphite", "Smoked", "Shadowed", "Ink"]
        } else {
            if t.saturation > 0.62 { words += ["Vivid", "Electric", "Radiant", "Charged", "Bold"] }
            else if t.saturation < 0.3 { words += ["Muted", "Dusty", "Weathered", "Faded", "Velvet"] }
            if t.brightness < 0.38 { words += ["Deep", "Midnight", "Inkwell", "Lowlight"] }
            else if t.brightness > 0.78 { words += ["Bright", "Airy", "Luminous", "Sunwashed"] }
            // A palette spanning many hues isn't "a blue palette with extras" —
            // say so, instead of implying the signature family covers it all.
            if t.hueSpread > 0.45 { words += ["Prismatic", "Spectrum", "Kaleidoscopic"] }
            if isWarm(t.hue) { words += ["Warm", "Sunlit", "Embered"] } else { words += ["Cool", "Shaded", "Glacial"] }
            if t.spread > 0.5 { words += ["Layered", "Contrasted", "Tonal"] }
        }
        return words
    }

    /// The palette's dominant color family — what a person would call it.
    private static func familyWord(for t: Traits) -> String {
        guard !t.isNeutral else {
            return t.brightness > 0.7 ? "Linen" : (t.brightness < 0.3 ? "Graphite" : "Stone")
        }
        let deg = t.hue * 360
        // Judged on the signature color's own brightness, so a dark palette
        // with one bright accent still names that accent correctly.
        let warmDeep = t.familyBrightness < 0.45
        switch deg {
        case ..<12:   return warmDeep ? "Garnet" : "Coral"
        case ..<26:   return warmDeep ? "Terracotta" : "Ember"
        case ..<42:   return warmDeep ? "Copper" : "Apricot"
        case ..<55:   return warmDeep ? "Bronze" : "Honey"
        case ..<70:   return warmDeep ? "Olive" : "Citron"
        case ..<95:   return warmDeep ? "Moss" : "Meadow"
        case ..<140:  return warmDeep ? "Pine" : "Sage"
        case ..<165:  return warmDeep ? "Juniper" : "Seaglass"
        case ..<190:  return warmDeep ? "Teal" : "Lagoon"
        case ..<215:  return warmDeep ? "Harbor" : "Sky"
        case ..<245:  return warmDeep ? "Ocean" : "Cornflower"
        case ..<270:  return warmDeep ? "Indigo" : "Periwinkle"
        case ..<295:  return warmDeep ? "Plum" : "Lilac"
        case ..<320:  return warmDeep ? "Mulberry" : "Orchid"
        case ..<340:  return warmDeep ? "Wine" : "Rose"
        default:      return warmDeep ? "Crimson" : "Blush"
        }
    }

    /// Evocative closers, chosen by lightness/temperature so the whole title
    /// reads coherently ("Terracotta Dusk", "Sky Gleam").
    private static func closerWords(for t: Traits) -> [String] {
        if t.brightness < 0.4 { return ["Dusk", "Nocturne", "Afterglow", "Velvet"] }
        if t.brightness > 0.75 { return ["Haze", "Daylight", "Gleam", "Lustre"] }
        return isWarm(t.hue)
            ? ["Bloom", "Kiln", "Hearth", "Solstice"]
            : ["Tide", "Current", "Mist", "Rain"]
    }

    private static let seedWords = [
        "Alder", "Atlas", "Cinder", "Cobalt", "Ember", "Fathom",
        "Grove", "Lumen", "Marrow", "Nimbus", "Onyx", "Quarry",
        "Rill", "Sable", "Trellis", "Verdigris",
    ]

    // MARK: - Helpers

    private static func isWarm(_ hue: Double) -> Bool {
        let deg = hue * 360
        return deg < 70 || deg > 320
    }

    /// Rejects titles that carry no information about the palette.
    private static func isGeneric(_ name: String) -> Bool {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return true }
        let genericExact: Set<String> = [
            "palette", "colors", "color palette", "colours", "colour palette",
            "generated palette", "generated", "my palette", "new palette",
            "untitled", "untitled palette", "custom palette", "simulator palette",
            "color scheme", "scheme", "swatch", "swatches", "theme", "my colors",
        ]
        if genericExact.contains(normalized) { return true }
        // A bare "… palette"/"… colors" with nothing else said.
        let words = normalized.split(separator: " ")
        if words.count == 1, ["palette", "colors", "theme", "scheme"].contains(String(words[0])) { return true }
        return false
    }

    /// Apple Intelligence often reaches for atmospheric filler words that do
    /// not distinguish one palette from the next. Reject them as standalone
    /// title words so the color-derived naming path can provide a useful,
    /// varied replacement instead.
    private static func usesClichedTitleLanguage(_ name: String) -> Bool {
        let clichedWords: Set<String> = [
            "whisper", "whispers", "whispering", "horizon", "horizons",
            "harmony", "harmonies", "dream", "dreams", "ethereal",
            "timeless", "serene", "reverie", "solace", "symphony",
        ]
        let words = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.contains { clichedWords.contains($0) }
    }

    private static func rotated(_ values: [String], by seed: Int) -> [String] {
        guard !values.isEmpty else { return [] }
        let offset = positiveModulo(seed, values.count)
        return values.indices.map { values[($0 + offset) % values.count] }
    }

    private static func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }

    /// Stable hash of the palette's colors — `hashValue` is randomized per
    /// process, so naming would not be deterministic across launches.
    private static func deterministicSeed(_ hexes: [String]) -> Int {
        var hash = 5381
        for scalar in hexes.joined(separator: ",").uppercased().unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return hash
    }

    private static func hsb(fromHex hex: String) -> (h: Double, s: Double, b: Double)? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
        guard UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &br, alpha: &a) else {
            return nil
        }
        return (Double(h), Double(s), Double(br))
    }
}
