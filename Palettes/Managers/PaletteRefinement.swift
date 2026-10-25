//
//  PaletteRefinement.swift
//  Palettes
//
//  "Describe a change" edits the palette on screen instead of starting over.
//  A generation keeps its recipe (brief, size, scheme, seed); a change is
//  read as steps relative to it ("darker", "warmer", "more colors", "make it
//  teal") and the palette is rebuilt from the same seed, so everything the
//  change doesn't mention stays put. On device the language model reads the
//  change; `heuristic(from:)` reads its words on the Simulator and whenever
//  the model fails.
//
//  Pure — no FoundationModels — so it is fully unit-testable.
//

import Foundation

/// Everything `PaletteBuilder` needs to rebuild a generated palette exactly.
struct GenerationRecipe: Equatable {
    var brief: PaletteBrief
    var size: Int
    /// The scheme as requested (may be `.auto`, which the seed resolves).
    var scheme: HarmonyScheme
    var seed: UInt64
    /// The main hue the builder actually used, for relative hue changes when
    /// the brief left the hue to the seed.
    var builtHue: Double?

    /// The recipe with `change` applied. The seed is kept, so a rebuild only
    /// moves what the change asks for.
    func applying(_ change: PaletteChange, lockedCount: Int) -> GenerationRecipe {
        var next = self
        next.brief.tone.lightness = Self.step(brief.tone.lightness, by: change.lightness,
                                              in: [.dark, .balanced, .light])
        next.brief.tone.chroma = Self.step(brief.tone.chroma, by: change.chroma,
                                           in: [.muted, .balanced, .vivid])

        if let hue = change.mainHue {
            next.brief.hue = hue
        } else if change.temperature != 0, let current = brief.hue ?? builtHue {
            next.brief.hue = Self.shift(hue: current, warmer: change.temperature > 0)
        }

        if let scheme = change.scheme, !self.scheme.isUIMode {
            next.scheme = scheme
        }

        if let size = change.size {
            next.size = size
        } else if change.sizeDelta != 0 {
            next.size = size + change.sizeDelta
        }
        next.size = min(12, max(2, max(lockedCount, next.size)))
        return next
    }

    private static func step<T: Equatable>(_ value: T, by delta: Int, in ladder: [T]) -> T {
        guard delta != 0, let index = ladder.firstIndex(of: value) else { return value }
        return ladder[min(ladder.count - 1, max(0, index + delta))]
    }

    /// Warm hues sit around orange (OKLCH ~55°), cool ones around blue
    /// (~240°). A step moves 35° toward that pole along the shorter way.
    static func shift(hue: Double, warmer: Bool) -> Double {
        let pole: Double = warmer ? 55 : 240
        var delta = (pole - hue).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let moved = hue + max(-35, min(35, delta))
        return (moved.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}

/// A change to a generated palette, relative to what it is now.
struct PaletteChange: Equatable {
    /// -1 darker, +1 lighter.
    var lightness = 0
    /// -1 more muted, +1 more vivid.
    var chroma = 0
    /// -1 cooler, +1 warmer.
    var temperature = 0
    /// A new main color, from a color word.
    var mainHue: Double?
    var scheme: HarmonyScheme?
    /// An exact color count ("5 colors"), or a step (`sizeDelta`).
    var size: Int?
    var sizeDelta = 0

    var isEmpty: Bool { self == PaletteChange() }

    /// Reads a change from its words.
    static func heuristic(from text: String) -> PaletteChange {
        let words = ColorVocabulary.tokens(text)
        let has = { (set: Set<String>) in words.contains(where: set.contains) }
        var change = PaletteChange()

        if has(darkerWords) { change.lightness = -1 } else if has(lighterWords) { change.lightness = 1 }
        if has(mutedWords) { change.chroma = -1 } else if has(vividWords) { change.chroma = 1 }
        if has(warmerWords) { change.temperature = 1 } else if has(coolerWords) { change.temperature = -1 }

        // The last color word wins: "less blue, more green" means green.
        change.mainHue = words.reversed().lazy.compactMap { ColorVocabulary.hueWords[$0] }.first

        if words.contains(where: ["monochrome", "monochromatic", "tonal"].contains) {
            change.scheme = .monochromatic
        } else if words.contains("complementary") {
            change.scheme = .complementary
        } else if words.contains("analogous") {
            change.scheme = .analogous
        } else if words.contains("triadic") {
            change.scheme = .triadic
        }

        if let count = exactCount(in: text) {
            change.size = count
        } else if has(["fewer", "less", "remove", "drop", "simpler", "smaller"]),
                  has(["color", "colors", "colour", "colours", "swatch", "swatches", "simpler", "smaller"]) {
            change.sizeDelta = -1
        } else if has(["more", "add", "another", "extra", "bigger", "larger"]),
                  has(["color", "colors", "colour", "colours", "swatch", "swatches", "bigger", "larger"]) {
            change.sizeDelta = 1
        }
        return change
    }

    /// "5 colors", "six colours".
    private static func exactCount(in text: String) -> Int? {
        let words = ColorVocabulary.tokens(text)
        let digits = text.lowercased()
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap(Int.init)
        let spelled = ["two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7,
                       "eight": 8, "nine": 9, "ten": 10, "eleven": 11, "twelve": 12]
        guard words.contains(where: ["color", "colors", "colour", "colours", "swatches"].contains) else { return nil }
        let count = digits.first ?? words.lazy.compactMap { spelled[$0] }.first
        return count.map { min(12, max(2, $0)) }
    }

    static let darkerWords: Set<String> = ["darker", "dark", "deeper", "deep", "moodier", "moody", "dimmer", "night", "nighttime", "shadowy", "richer"]
    static let lighterWords: Set<String> = ["lighter", "light", "paler", "pale", "airier", "airy", "pastel", "softer", "lift", "daytime", "brighter"]
    static let mutedWords: Set<String> = ["muted", "duller", "dull", "dustier", "dusty", "subtler", "subtle", "calmer", "calm", "desaturated", "faded", "earthier", "earthy", "greyer", "grayer", "toned"]
    static let vividWords: Set<String> = ["vivid", "vivider", "bolder", "bold", "saturated", "punchier", "punchy", "vibrant", "neon", "electric", "louder", "intense", "pop"]
    static let warmerWords: Set<String> = ["warmer", "warm", "warmth", "hotter", "sunnier", "cozier", "autumn", "autumnal", "fiery"]
    static let coolerWords: Set<String> = ["cooler", "cool", "colder", "cold", "icier", "icy", "frosty", "wintry", "winter"]
}
