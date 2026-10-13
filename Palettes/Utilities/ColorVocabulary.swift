//
//  ColorVocabulary.swift
//  Palettes
//
//  The words people use for colors, tied to OKLCH hue families. One source
//  for three jobs: reading a vibe into a hue and tone (PaletteBrief),
//  writing the plain descriptions the model names colors from, and
//  rejecting names that contradict their swatch ("Blue" on an orange,
//  "Dark" on a near-white, "Charcoal" on a saturated teal).
//

import Foundation

enum ColorVocabulary {

    // MARK: - Hue families

    /// Eight coarse families around the OKLCH hue circle, in ring order.
    enum Family: Int, CaseIterable {
        case pink, red, orange, yellow, green, teal, blue, purple

        var name: String {
            switch self {
            case .pink: return "pink"
            case .red: return "red"
            case .orange: return "orange"
            case .yellow: return "yellow"
            case .green: return "green"
            case .teal: return "teal"
            case .blue: return "blue"
            case .purple: return "purple"
            }
        }

        /// OKLCH hue at the family's center. A hue belongs to the nearest center.
        var center: Double {
            switch self {
            case .pink: return 0
            case .red: return 27
            case .orange: return 58
            case .yellow: return 100
            case .green: return 145
            case .teal: return 185
            case .blue: return 250
            case .purple: return 310
            }
        }
    }

    static func family(forHue hue: Double) -> Family {
        Family.allCases.min { OKLCH.hueDistance(hue, $0.center) < OKLCH.hueDistance(hue, $1.center) }!
    }

    /// Steps between two families around the ring (0 ... 4).
    static func ringDistance(_ a: Family, _ b: Family) -> Int {
        let d = abs(a.rawValue - b.rawValue)
        return min(d, Family.allCases.count - d)
    }

    // MARK: - Word lists

    /// Words that name a hue, mapped to an OKLCH hue in degrees.
    static let hueWords: [String: Double] = [
        "red": 29, "crimson": 20, "scarlet": 30, "ruby": 15, "cherry": 20, "garnet": 18,
        "wine": 10, "burgundy": 12, "maroon": 22, "brick": 35, "rust": 45, "terracotta": 45,
        "coral": 38, "salmon": 35, "vermilion": 35,
        "orange": 60, "tangerine": 55, "apricot": 65, "peach": 60, "copper": 55, "bronze": 70,
        "amber": 75, "caramel": 70, "brown": 55, "chocolate": 45, "coffee": 55, "mocha": 50,
        "tan": 75, "ochre": 85, "cinnamon": 50,
        "yellow": 105, "gold": 95, "golden": 95, "honey": 85, "mustard": 100, "lemon": 108,
        "butter": 100, "saffron": 85, "citron": 110, "olive": 115,
        "lime": 135, "green": 145, "emerald": 160, "jade": 160, "mint": 165, "sage": 140,
        "moss": 125, "pine": 155, "fern": 140, "chartreuse": 125, "pistachio": 130,
        "teal": 190, "cyan": 200, "aqua": 195, "turquoise": 185, "lagoon": 195, "seafoam": 175,
        "blue": 260, "navy": 262, "cobalt": 262, "azure": 240, "sky": 235, "sapphire": 262,
        "denim": 255, "cerulean": 240, "indigo": 275, "ultramarine": 268, "cornflower": 265,
        "violet": 295, "purple": 310, "lavender": 300, "lilac": 310, "plum": 330,
        "amethyst": 305, "mauve": 330, "orchid": 330, "grape": 310, "periwinkle": 285,
        "magenta": 330, "fuchsia": 335, "pink": 0, "rose": 5, "blush": 10, "flamingo": 5,
        "raspberry": 355, "aquamarine": 170,
    ]

    /// How much chroma and lightness a hue noun needs, and how far its own
    /// hue may sit from the swatch's. The hue ring alone lets "tangerine"
    /// name a beige and "aquamarine" a sky blue: a noun carries intensity
    /// ("tangerine" is loud, "beige" is quiet) and a narrower hue than its
    /// family. `hue` falls back to the noun's `hueWords` entry.
    struct Envelope {
        var minChroma = 0.0
        var maxChroma = 1.0
        var minLightness = 0.0
        var maxLightness = 1.0
        var hueTolerance: Double?
    }

    static let envelopes: [String: Envelope] = [
        "tangerine": Envelope(minChroma: 0.10, hueTolerance: 30),
        "aquamarine": Envelope(minChroma: 0.07, hueTolerance: 30),
        "turquoise": Envelope(minChroma: 0.06, hueTolerance: 30),
        "coral": Envelope(minChroma: 0.10, hueTolerance: 35),
        "neon": Envelope(minChroma: 0.15),
        "cerulean": Envelope(minChroma: 0.08, minLightness: 0.5, hueTolerance: 30),
        "beige": Envelope(maxChroma: 0.07, minLightness: 0.7),
        "tan": Envelope(maxChroma: 0.07),
        "sand": Envelope(maxChroma: 0.07, minLightness: 0.6),
        "taupe": Envelope(maxChroma: 0.07),
        "khaki": Envelope(maxChroma: 0.13),
        "navy": Envelope(maxLightness: 0.40),
        "midnight": Envelope(maxLightness: 0.40),
    ]

    /// Places and moods that imply a hue. Only used to read a vibe — a
    /// color named "Ocean Mist" or "Autumn Dusk" can be any color.
    static let moodHues: [String: Double] = [
        "sunset": 45, "sunrise": 55, "autumn": 55, "fall": 55, "desert": 75, "beach": 85,
        "ocean": 240, "sea": 230, "forest": 150, "jungle": 150, "spring": 140, "meadow": 140,
        "winter": 240, "ice": 220, "arctic": 220, "night": 265, "midnight": 265,
        "fire": 35, "lava": 30, "candy": 0, "berry": 350, "earth": 60, "earthy": 60,
        "clay": 45, "sand": 80, "sandy": 80, "harbor": 240, "rain": 245, "storm": 255,
        "leaf": 140, "leaves": 140, "citrus": 100, "tropical": 160,
    ]

    /// Words that name a grey rather than a hue.
    static let greyWords: Set<String> = [
        "grey", "gray", "black", "charcoal", "graphite", "slate", "ash", "smoke", "silver",
        "ink", "onyx", "jet", "stone", "fog", "pewter", "steel", "concrete", "cement",
    ]

    /// Words that name an off-white.
    static let whiteWords: Set<String> = ["white", "ivory", "cream", "linen", "bone", "pearl", "snow", "chalk"]

    static let darkWords: Set<String> = ["dark", "deep", "midnight", "night", "ink", "shadow", "dusk", "abyss", "noir"]
    static let lightWords: Set<String> = ["pale", "light", "pastel", "ice", "icy", "mist", "misty", "cream", "snow", "frost", "frosted", "chalk"]
    static let vividWords: Set<String> = ["vivid", "neon", "electric", "bright", "hot", "radiant", "fluorescent"]

    // Tone words for reading a vibe.
    static let darkToneWords: Set<String> = ["dark", "moody", "midnight", "night", "noir", "gothic", "deep", "shadow", "shadowy", "dusk", "nocturnal"]
    static let lightToneWords: Set<String> = ["light", "airy", "pastel", "soft", "morning", "fresh", "breezy", "cloud", "cloudy", "delicate"]
    static let mutedToneWords: Set<String> = ["muted", "dusty", "vintage", "faded", "calm", "earthy", "rustic", "pastel", "soft", "subtle", "natural", "cozy", "washed"]
    static let vividToneWords: Set<String> = ["vivid", "neon", "bold", "electric", "vibrant", "bright", "saturated", "punchy", "tropical", "pop", "arcade"]

    /// Lowercased letter-only words.
    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - Describing a color

    /// The plain description the model names a color from, e.g.
    /// "lightness=dark intensity=muted hue=teal". Written by code from the
    /// actual swatch, so the model never has to guess a color from its hex
    /// code. Deliberately not name-shaped ("dark, muted teal" got echoed
    /// back as the name).
    static func describe(hex: String) -> String {
        guard let color = OKLCH(hex: hex) else { return "unknown" }
        let lightness: String
        switch color.L {
        case ..<0.32: lightness = "very dark"
        case ..<0.48: lightness = "dark"
        case ..<0.66: lightness = "medium"
        case ..<0.84: lightness = "light"
        default: lightness = "very light"
        }
        let family = family(forHue: color.h).name
        if color.C < 0.03 {
            let hue = color.C >= 0.012 ? "grey leaning \(family)" : "neutral grey"
            return "lightness=\(lightness) intensity=none hue=\(hue)"
        }
        let chroma = color.C < 0.07 ? "muted" : (color.C < 0.14 ? "moderate" : "vivid")
        return "lightness=\(lightness) intensity=\(chroma) hue=\(family)"
    }

    // MARK: - Checking a name

    /// Whether `name` could describe `hex`. Rejects names that put the
    /// color in a hue family two or more steps away on the wheel, a hue on
    /// a true grey, only grey words on a clearly colored swatch, or a
    /// lightness or intensity the swatch doesn't have.
    static func isPlausible(name: String, forHex hex: String) -> Bool {
        guard let color = OKLCH(hex: hex) else { return false }
        return isPlausible(name: name, for: color)
    }

    static func isPlausible(name: String, for color: OKLCH) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = tokens(trimmed)
        guard !words.isEmpty, words.count <= 4, trimmed.count <= 28 else { return false }
        guard trimmed.rangeOfCharacter(from: .decimalDigits) == nil, !trimmed.contains("#") else { return false }

        let named = words.compactMap { hueWords[$0] }.map { family(forHue: $0) }
        let own = family(forHue: color.h)
        for word in words {
            guard let envelope = envelopes[word] else { continue }
            guard color.C >= envelope.minChroma, color.C <= envelope.maxChroma,
                  color.L >= envelope.minLightness, color.L <= envelope.maxLightness else { return false }
            if let tolerance = envelope.hueTolerance, let hue = hueWords[word], color.C >= 0.02,
               OKLCH.hueDistance(color.h, hue) > tolerance { return false }
        }
        if color.C < 0.006 {
            // A true grey has no hue to name.
            if !named.isEmpty { return false }
        } else if named.allSatisfy({ ringDistance($0, own) > 1 }), !named.isEmpty {
            // Every hue word is off: "Blue Lagoon" on an orange. One that
            // fits is enough for a compound like "Rose Gold".
            return false
        }
        if named.isEmpty {
            if color.C >= 0.06, words.contains(where: greyWords.contains) { return false }
            if words.contains(where: whiteWords.contains), color.L < 0.8 || color.C >= 0.1 { return false }
        }
        if color.L > 0.78, words.contains(where: darkWords.contains) { return false }
        if color.L < 0.40, words.contains(where: lightWords.contains) { return false }
        if color.C < 0.06, words.contains(where: vividWords.contains) { return false }
        return true
    }

    // MARK: - Model-name hygiene

    /// Adjectives about mood that models put in front of a color word
    /// ("gentle, muted aquamarine"). They say nothing about the swatch.
    static let moodAdjectives: Set<String> = [
        "gentle", "steady", "soft", "rich", "mellow", "calm", "bold", "warm", "cool", "subtle",
        "quiet", "lovely", "serene", "tranquil", "cozy", "lush", "radiant", "pure", "classic",
        "delicate", "smooth", "bright", "crisp", "fresh", "elegant", "luxurious",
    ]

    /// Our own description words; a name that uses one is echoing the prompt.
    static let descriptorWords: Set<String> = [
        "muted", "vivid", "moderate", "light", "dark", "medium", "lightness", "intensity", "hue", "neutral",
    ]

    /// Whether a model-proposed name is a clean color name: one to three
    /// words, no comma, no echo of our description words, and not a mood
    /// adjective stuck in front of a bare hue word ("Gentle Aquamarine").
    /// Stricter than `isPlausible`, which also vets dictionary names such
    /// as "Dark Red" and "Warm Gray".
    static func isCleanModelName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(","), !trimmed.contains(";"), !trimmed.contains("="), !trimmed.contains(":") else { return false }
        let words = tokens(trimmed)
        guard (1...3).contains(words.count) else { return false }
        if words.contains(where: descriptorWords.contains) { return false }
        if words.count > 1, let first = words.first, moodAdjectives.contains(first) {
            let rest = words.dropFirst()
            if rest.allSatisfy({ hueWords[$0] != nil || greyWords.contains($0) || whiteWords.contains($0) }) { return false }
        }
        return true
    }

    /// Whether a palette title's color words match colors in the palette.
    /// A title with no color words always passes.
    static func isPlausibleTitle(_ title: String, forHexes hexes: [String]) -> Bool {
        let named = tokens(title).compactMap { hueWords[$0] }.map { family(forHue: $0) }
        guard !named.isEmpty else { return true }
        let present = hexes.compactMap { OKLCH(hex: $0) }.filter { $0.C >= 0.04 }.map { family(forHue: $0.h) }
        return named.allSatisfy { word in present.contains { ringDistance($0, word) <= 1 } }
    }
}
