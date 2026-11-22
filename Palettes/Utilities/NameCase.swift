//
//  NameCase.swift
//  Palettes
//
//  One casing rule for every name a user sees (colors, palettes): Title Case,
//  except minor words, and without flattening names that already carry
//  deliberate capitals ("iPhone Blue", "UI Red").
//

import Foundation

nonisolated enum NameCase {
    private static let minorWords: Set<String> = [
        "of", "and", "the", "in", "on", "at", "to", "a", "an", "or", "for"
    ]

    /// Trims and collapses whitespace, then capitalizes each word. A word that
    /// already has an uppercase letter is kept as typed; nothing is lowercased.
    /// Minor words stay lowercase unless first or last. Hyphenated parts are
    /// each capitalized.
    static func titled(_ s: String) -> String {
        let words = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return "" }
        let last = words.count - 1
        return words.enumerated().map { index, word in
            if index != 0, index != last, minorWords.contains(word.lowercased()) {
                // Keep a minor word as typed only if it has deliberate capitals.
                return word.contains(where: \.isUppercase) ? word : word.lowercased()
            }
            return capitalizeWord(word)
        }.joined(separator: " ")
    }

    private static func capitalizeWord(_ word: String) -> String {
        if word.contains("-") {
            return word.split(separator: "-", omittingEmptySubsequences: false)
                .map { capitalizePart(String($0)) }
                .joined(separator: "-")
        }
        return capitalizePart(word)
    }

    private static func capitalizePart(_ part: String) -> String {
        guard !part.isEmpty, !part.contains(where: \.isUppercase) else { return part }
        return part.prefix(1).uppercased() + part.dropFirst()
    }
}
