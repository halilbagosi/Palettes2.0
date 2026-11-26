//
//  StyleDeck.swift
//  Palettes
//
//  Generating again from the same colors, mode and vibe should look
//  different. The deck hands out a mode's styles in turn, so every style
//  shows before any repeats. Interface modes shuffle, and a reshuffle never
//  starts with the style that just showed. Auto with the user's colors walks
//  the styles best-suited first. Session memory only: nothing here is persisted.
//
//  `StyleDeck` is pure and takes its random source, so it is fully
//  unit-testable. `StyleDeckStore` is the app's one instance.
//

import Foundation

/// What counts as "the same request": the user's colors in order, the
/// mode, and the vibe's words.
struct StyleDeckKey: Hashable {
    let anchors: [String]
    let scheme: HarmonyScheme
    let vibe: String

    init(anchors: [String], scheme: HarmonyScheme, vibe: String?) {
        self.anchors = PaletteBuilder.normalize(anchors)
        self.scheme = scheme
        self.vibe = (vibe ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct StyleDeck {
    static let capacity = 32

    private struct Round {
        var order: [PaletteStyle]
        var position: Int
        /// The style drawn last, so a new round never starts by repeating it.
        var last: PaletteStyle? = nil
    }

    private var rounds: [StyleDeckKey: Round] = [:]
    /// Keys from least to most recently drawn.
    private var recency: [StyleDeckKey] = []

    var keyCount: Int { rounds.count }

    func contains(_ key: StyleDeckKey) -> Bool { rounds[key] != nil }

    /// The next style for `key`.
    /// - `ordered`: every round walks `candidates` in the given order (Auto's
    ///   best-fit ranking). Otherwise each round is a shuffle.
    /// - `first`: leads a fresh shuffled deck (a vibe's harmony).
    /// - Returns nil only when there are no candidates.
    mutating func next<G: RandomNumberGenerator>(
        for key: StyleDeckKey,
        candidates: [PaletteStyle],
        first: PaletteStyle? = nil,
        ordered: Bool = false,
        using rng: inout G
    ) -> PaletteStyle? {
        guard !candidates.isEmpty else { return nil }
        var round: Round
        if let existing = rounds[key], Set(existing.order) == Set(candidates) {
            round = existing
        } else {
            // A fresh deck, or the candidates changed under this key (a vibe
            // read differently): an ordered walk resumes after the last style,
            // a shuffle never starts with it.
            let last = rounds[key]?.last
            round = Round(order: Self.makeOrder(candidates, ordered: ordered, first: last == nil ? first : nil, after: last, using: &rng), position: 0, last: last)
            if ordered, let last, let index = round.order.firstIndex(of: last) { round.position = index + 1 }
        }
        if round.position >= round.order.count {
            round.order = Self.makeOrder(candidates, ordered: ordered, first: nil, after: round.last, using: &rng)
            round.position = 0
        }
        let style = round.order[round.position]
        round.position += 1
        round.last = style
        store(round, for: key)
        return style
    }

    /// A round's order: the given order, or a shuffle that leads with `first`
    /// and never starts with `last` (the style just shown).
    private static func makeOrder<G: RandomNumberGenerator>(
        _ candidates: [PaletteStyle], ordered: Bool, first: PaletteStyle?, after last: PaletteStyle?, using rng: inout G
    ) -> [PaletteStyle] {
        guard !ordered else { return candidates }
        var order = candidates.shuffled(using: &rng)
        if let first, let index = order.firstIndex(of: first) { order.swapAt(0, index) }
        if order.count > 1, order[0] == last { order.swapAt(0, 1) }
        return order
    }

    private mutating func store(_ round: Round, for key: StyleDeckKey) {
        if rounds[key] == nil, rounds.count >= Self.capacity, let oldest = recency.first {
            rounds[oldest] = nil
            recency.removeFirst()
        }
        rounds[key] = round
        recency.removeAll { $0 == key }
        recency.append(key)
    }
}

// MARK: - Auto

extension StyleDeck {
    /// The Auto styles that fit the user's colors and vibe, and how to walk them.
    /// - Colors that imply a harmony keep that harmony's style plus the tone
    ///   styles, which then build on the implied harmony.
    /// - A vibe's tone drops the styles that contradict it.
    /// - The colors' implied harmony leads; otherwise a vibe's harmony leads.
    /// - With the user's colors, the rest go best-suited first, every round
    ///   (`ordered`). With none there's nothing to suit, so the deck shuffles.
    static func autoCandidates(anchors: [String], brief: PaletteBrief) -> (styles: [PaletteStyle], first: PaletteStyle?, ordered: Bool) {
        let colors = PaletteBuilder.normalize(anchors).compactMap { OKLCH(hex: $0) }
        let implied = PaletteBuilder.impliedHarmony(of: colors)
        var styles: [PaletteStyle]
        switch implied {
        case .monochromatic?:
            styles = [.monochromePop, .pastel, .jewelTones]
        case let harmony?:
            styles = [PaletteStyle.treatment(for: harmony)].compactMap { $0 } + [.pastel, .jewelTones, .earthy]
        case nil:
            styles = PaletteStyle.deck(for: .auto)
        }
        // A vibe that names two colors is not a one-hue palette.
        if colors.isEmpty, brief.secondaryHue != nil {
            styles.removeAll { $0 == .monochromePop }
        }

        var removed: Set<PaletteStyle> = []
        switch brief.tone.lightness {
        case .light: removed.insert(.jewelTones)
        case .dark: removed.insert(.pastel)
        case .balanced: break
        }
        switch brief.tone.chroma {
        case .vivid: removed.formUnion([.pastel, .earthy])
        case .muted: removed.formUnion([.jewelTones, .triadicPlayful])
        case .balanced: break
        }
        let kept = styles.filter { !removed.contains($0) }
        if !kept.isEmpty { styles = kept }

        let leadHarmony = implied ?? brief.scheme
        let lead = leadHarmony.flatMap { PaletteStyle.treatment(for: $0) }.flatMap { styles.contains($0) ? $0 : nil }
        guard let basis = colors.first(where: { $0.C >= 0.03 }) ?? colors.first else {
            return (styles, lead, false)
        }
        let ranked = PaletteStyle.ranked(styles.filter { $0 != lead }, for: basis)
        return ((lead.map { [$0] } ?? []) + ranked, nil, true)
    }
}

/// The app's one deck, kept for the session only.
final class StyleDeckStore {
    static let shared = StyleDeckStore()

    private var deck = StyleDeck()
    private var rng = SystemRandomNumberGenerator()

    init() {}

    nonisolated deinit {}

    func next(for key: StyleDeckKey, candidates: [PaletteStyle], first: PaletteStyle? = nil, ordered: Bool = false) -> PaletteStyle? {
        deck.next(for: key, candidates: candidates, first: first, ordered: ordered, using: &rng)
    }
}
