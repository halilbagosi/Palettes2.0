//
//  PaletteBrief.swift
//  Palettes
//
//  What a vibe asks of a palette, in terms the builder understands: a main
//  hue, a tone, and optionally a harmony. On device the language model
//  fills this in; `heuristic(from:)` reads the vibe's own words instead, on
//  the Simulator and whenever the model fails. Either way the model never
//  chooses color values.
//

import Foundation

struct PaletteBrief: Equatable {
    /// OKLCH hue (degrees) of the palette's main color, if the vibe names one.
    var hue: Double?
    /// OKLCH hue of a second color family the vibe names ("ocean sunset":
    /// blue, then orange). The builder gives it to the secondary and accent
    /// slots instead of a scheme's rotation. nil for a one-color vibe.
    var secondaryHue: Double?
    var tone: PaletteTone
    /// A harmonic scheme the vibe calls for. Never `.auto` or an interface mode.
    var scheme: HarmonyScheme?
    /// How many colors the vibe calls for (4...8), when the model suggests one.
    /// nil from the heuristic, which cannot judge it.
    var suggestedSize: Int?

    static let neutral = PaletteBrief(hue: nil, tone: .balanced, scheme: nil)

    /// Reads a vibe from its words: a color word sets the hue (a place or
    /// mood word only if no color word appears), tone words set lightness
    /// and saturation, and harmony words set the scheme.
    static func heuristic(from vibe: String) -> PaletteBrief {
        let words = ColorVocabulary.tokens(vibe)
        let hues = vibeHues(in: words)
        let hue = hues.first
        let secondaryHue = secondHue(after: hue, in: hues)

        var tone = PaletteTone.balanced
        if words.contains(where: ColorVocabulary.darkToneWords.contains) {
            tone.lightness = .dark
        } else if words.contains(where: ColorVocabulary.lightToneWords.contains) {
            tone.lightness = .light
        }
        if words.contains(where: ColorVocabulary.mutedToneWords.contains) {
            tone.chroma = .muted
        } else if words.contains(where: ColorVocabulary.vividToneWords.contains) {
            tone.chroma = .vivid
        }

        var scheme: HarmonyScheme?
        if words.contains(where: ["monochrome", "monochromatic", "tonal"].contains) {
            scheme = .monochromatic
        } else if words.contains("complementary") {
            scheme = .complementary
        } else if words.contains("analogous") {
            scheme = .analogous
        } else if words.contains("triadic") {
            scheme = .triadic
        }
        return PaletteBrief(hue: hue, secondaryHue: secondaryHue, tone: tone, scheme: scheme)
    }

    /// The hues a vibe's words imply, in the order the main color is chosen:
    /// color words first, then place and mood words, each in reading order.
    static func vibeHues(in words: [String]) -> [Double] {
        words.compactMap { ColorVocabulary.hueWords[$0] }
            + words.compactMap { ColorVocabulary.moodHues[$0] }
    }

    /// The first hue clearly apart from `main`: "ocean sunset" is a blue and
    /// an orange, "ocean sea" is only a blue.
    static func secondHue(after main: Double?, in hues: [Double]) -> Double? {
        guard let main else { return nil }
        return hues.first { OKLCH.hueDistance($0, main) >= 45 }
    }

    /// The final palette size: an explicit request wins, else the model's
    /// suggestion, else 6. Never below the number of locked colors; 2...12.
    static func resolvedSize(requested: Int?, locked: Int, suggested: Int?) -> Int {
        min(12, max(2, max(locked, requested ?? suggested ?? 6)))
    }

    /// The OKLCH hue of a color word such as "terracotta" or "navy blue":
    /// the vocabulary first, then the color dictionary. nil for words that
    /// name no hue (including greys).
    static func hue(forColorWord word: String) -> Double? {
        let words = ColorVocabulary.tokens(word)
        if let hue = words.lazy.compactMap({ ColorVocabulary.hueWords[$0] }).first
            ?? words.lazy.compactMap({ ColorVocabulary.moodHues[$0] }).first {
            return hue
        }
        guard let hex = ColorNamer.hex(forName: word),
              let color = OKLCH(hex: hex),
              color.C >= 0.03 else { return nil }
        return color.h
    }
}
