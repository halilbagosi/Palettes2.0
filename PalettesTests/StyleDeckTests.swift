//
//  StyleDeckTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class StyleDeckTests: XCTestCase {

    private let light = PaletteStyle.deck(for: .uiLight)
    private let auto = PaletteStyle.deck(for: .auto)

    private func key(_ anchors: [String] = ["#3060A0"], _ scheme: HarmonyScheme = .uiLight, _ vibe: String? = nil) -> StyleDeckKey {
        StyleDeckKey(anchors: anchors, scheme: scheme, vibe: vibe)
    }

    // MARK: - Fit

    func testEachColorKindSuitsItsStyle() {
        let cases: [(String, PaletteStyle)] = [
            ("#808080", .monochromePop),     // grey
            ("#FFF2A0", .pastel),            // pale yellow
            ("#8B5A2B", .earthy),            // warm muted brown
            ("#1E3A8A", .jewelTones),        // deep saturated navy
            ("#FF5E7A", .complementaryPop),  // vivid coral
            ("#FFD700", .complementaryPop),  // vivid gold: bright, not pastel
            ("#A0E000", .complementaryPop),  // vivid lime
            ("#808000", .earthy),            // olive
            ("#C46A4A", .earthy),            // terracotta
            ("#C9A227", .earthy),            // mustard
            ("#3B2414", .earthy),            // dark brown
        ]
        for (hex, expected) in cases {
            let color = OKLCH(hex: hex)!
            XCTAssertEqual(PaletteStyle.ranked(auto, for: color).first, expected, "\(hex) L \(color.L) C \(color.C) h \(color.h)")
        }
    }

    func testRankingKeepsEveryStyleAndBreaksTiesByDeckOrder() {
        XCTAssertEqual(Set(PaletteStyle.ranked(auto, for: OKLCH(hex: "#3060A0")!)), Set(auto))
        // A soft mid blue: Monochrome + Pop and Triadic Playful tie at 1, and Pastel, Jewel Tones and Earthy tie at 0. Ties keep deck order.
        let soft = OKLCH(L: 0.6, C: 0.05, h: 250)
        XCTAssertEqual(PaletteStyle.ranked(auto, for: soft),
                       [.analogous603010, .splitComplementary, .complementaryPop, .monochromePop, .triadicPlayful, .pastel, .jewelTones, .earthy])
    }

    func testInterfaceStylesHaveNoFit() {
        for style in light + PaletteStyle.deck(for: .uiDark) {
            XCTAssertEqual(style.fit(for: OKLCH(hex: "#3060A0")!), 0, "\(style)")
        }
    }

    // MARK: - Drawing

    func testEveryStyleShowsOnceBeforeAnyRepeats() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 3)
        let drawn = (0..<light.count).compactMap { _ in deck.next(for: key(), candidates: light, using: &rng) }
        XCTAssertEqual(drawn.count, light.count)
        XCTAssertEqual(Set(drawn), Set(light))
    }

    func testNoRepeatAcrossAReshuffle() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 11)
        var previous: PaletteStyle?
        for round in 0..<50 {
            var seen: Set<PaletteStyle> = []
            for _ in 0..<light.count {
                let style = deck.next(for: key(), candidates: light, using: &rng)!
                XCTAssertNotEqual(style, previous, "round \(round)")
                seen.insert(style)
                previous = style
            }
            XCTAssertEqual(seen, Set(light), "round \(round)")
        }
    }

    func testOrderedDeckWalksTheGivenOrderEveryRound() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 4)
        let order: [PaletteStyle] = [.pastel, .analogous603010, .earthy]
        let drawn = (0..<6).compactMap { _ in deck.next(for: key(["#FFF2A0"], .auto), candidates: order, ordered: true, using: &rng) }
        XCTAssertEqual(drawn, order + order)
    }

    func testKeysAreIndependent() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 5)
        for _ in 0..<3 { _ = deck.next(for: key(["#3060A0"]), candidates: light, using: &rng) }
        let other = (0..<light.count).compactMap { _ in deck.next(for: key(["#FF5E7A"]), candidates: light, using: &rng) }
        XCTAssertEqual(Set(other), Set(light))
    }

    func testKeyNormalizesItsInputs() {
        XCTAssertEqual(StyleDeckKey(anchors: ["3060a0"], scheme: .uiLight, vibe: "  Calm Ocean "),
                       StyleDeckKey(anchors: ["#3060A0"], scheme: .uiLight, vibe: "calm ocean"))
        XCTAssertNotEqual(key(["#3060A0"], .uiLight), key(["#3060A0"], .uiDark))
    }

    func testOldestKeyIsDroppedPastCapacity() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 1)
        let keys = (0...StyleDeck.capacity).map { key([String(format: "#%06X", $0 * 4099)]) }
        for k in keys { _ = deck.next(for: k, candidates: light, using: &rng) }
        XCTAssertEqual(deck.keyCount, StyleDeck.capacity)
        XCTAssertFalse(deck.contains(keys[0]))
        XCTAssertTrue(deck.contains(keys[StyleDeck.capacity]))
    }

    func testFirstStyleLeadsAFreshShuffledDeck() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 2)
        XCTAssertEqual(deck.next(for: key(), candidates: light, first: .highContrast, using: &rng), .highContrast)
        let rest = (1..<light.count).compactMap { _ in deck.next(for: key(), candidates: light, first: .highContrast, using: &rng) }
        XCTAssertFalse(rest.contains(.highContrast), "first only leads; it doesn't repeat")
    }

    func testNoCandidatesGiveNoStyle() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 1)
        XCTAssertNil(deck.next(for: key(), candidates: [], using: &rng))
    }

    func testStoreCyclesThroughADeck() {
        let store = StyleDeckStore()
        let drawn = (0..<light.count).compactMap { _ in store.next(for: key(), candidates: light) }
        XCTAssertEqual(Set(drawn), Set(light))
    }

    // MARK: - Auto candidates

    func testAutoWithoutColorsShufflesTheFullDeck() {
        let result = StyleDeck.autoCandidates(anchors: [], brief: .neutral)
        XCTAssertEqual(Set(result.styles), Set(auto))
        XCTAssertFalse(result.ordered)
        XCTAssertNil(result.first)
    }

    func testAutoWithAColorRanksBestFitFirst() {
        let result = StyleDeck.autoCandidates(anchors: ["#FFF2A0"], brief: .neutral)
        XCTAssertTrue(result.ordered)
        XCTAssertEqual(result.styles, PaletteStyle.ranked(auto, for: OKLCH(hex: "#FFF2A0")!))
        XCTAssertEqual(result.styles.first, .pastel)
    }

    func testImpliedHarmonyLeadsThenTheToneTreatmentsByFit() {
        let result = StyleDeck.autoCandidates(anchors: ["#3366CC", "#CC6633"], brief: .neutral)
        XCTAssertTrue(result.ordered)
        XCTAssertEqual(result.styles.first, .triadicPlayful)
        XCTAssertEqual(Set(result.styles), [.triadicPlayful, .pastel, .jewelTones, .earthy])
    }

    func testGreyColorsKeepMonochromePopPastelAndJewel() {
        let result = StyleDeck.autoCandidates(anchors: ["#808080"], brief: .neutral)
        XCTAssertEqual(result.styles.first, .monochromePop)
        XCTAssertEqual(Set(result.styles), [.monochromePop, .pastel, .jewelTones])
    }

    func testVibeToneRemovesContradictingTreatments() {
        func styles(_ lightness: PaletteTone.Lightness = .balanced, _ chroma: PaletteTone.Chroma = .balanced) -> [PaletteStyle] {
            var brief = PaletteBrief.neutral
            brief.tone = PaletteTone(lightness: lightness, chroma: chroma)
            return StyleDeck.autoCandidates(anchors: [], brief: brief).styles
        }
        XCTAssertFalse(styles(.light).contains(.jewelTones))
        XCTAssertFalse(styles(.dark).contains(.pastel))
        XCTAssertFalse(styles(.balanced, .vivid).contains(.pastel))
        XCTAssertFalse(styles(.balanced, .vivid).contains(.earthy))
        XCTAssertFalse(styles(.balanced, .muted).contains(.jewelTones))
        XCTAssertFalse(styles(.balanced, .muted).contains(.triadicPlayful))
    }

    func testVibeHarmonyLeads() {
        var brief = PaletteBrief.neutral
        brief.scheme = .triadic
        // No colors: it leads the shuffle.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: [], brief: brief).first, .triadicPlayful)
        // One color: it leads the ranking.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: ["#FFF2A0"], brief: brief).styles.first, .triadicPlayful)
        // Colors that imply a harmony outrank the vibe's.
        XCTAssertEqual(StyleDeck.autoCandidates(anchors: ["#3366CC", "#4D7FE0"], brief: brief).styles.first, .analogous603010)
    }

    func testTwoHueVibeDropsMonochrome() {
        var brief = PaletteBrief.neutral
        brief.secondaryHue = 40
        XCTAssertFalse(StyleDeck.autoCandidates(anchors: [], brief: brief).styles.contains(.monochromePop))
    }

    func testRecentlyDrawnKeySurvivesEviction() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 1)
        let keys = (0...StyleDeck.capacity).map { key([String(format: "#%06X", $0 * 4099)]) }
        for k in keys.dropLast() { _ = deck.next(for: k, candidates: light, using: &rng) }
        _ = deck.next(for: keys[0], candidates: light, using: &rng)   // key 0 is now the most recent
        _ = deck.next(for: keys[StyleDeck.capacity], candidates: light, using: &rng)
        XCTAssertTrue(deck.contains(keys[0]), "least recently used, not first inserted, is dropped")
        XCTAssertFalse(deck.contains(keys[1]))
    }

    func testChangedCandidatesNeverRepeatTheLastStyle() {
        var deck = StyleDeck()
        var rng = SplitMix64(seed: 8)
        let k = key(["#FFF2A0"], .auto)
        let full: [PaletteStyle] = [.pastel, .analogous603010, .earthy, .splitComplementary]
        XCTAssertEqual(deck.next(for: k, candidates: full, ordered: true, using: &rng), .pastel)
        // The vibe reads differently this time and drops Earthy: the walk resumes after Pastel.
        let fewer: [PaletteStyle] = [.pastel, .analogous603010, .splitComplementary]
        XCTAssertEqual(deck.next(for: k, candidates: fewer, ordered: true, using: &rng), .analogous603010)
        // Shuffled decks don't repeat across a change either.
        for seed: UInt64 in 0..<30 {
            var shuffled = StyleDeck()
            var r = SplitMix64(seed: seed)
            let shown = shuffled.next(for: key(), candidates: light, using: &r)!
            let next = shuffled.next(for: key(), candidates: Array(light.dropLast()), using: &r)
            XCTAssertNotEqual(next, shown, "seed \(seed)")
        }
    }

    func testVibeNamingANonEarthyColorDropsEarthy() {
        var brief = PaletteBrief.neutral
        brief.hue = 240
        XCTAssertFalse(StyleDeck.autoCandidates(anchors: [], brief: brief).styles.contains(.earthy))
        brief.hue = 55
        XCTAssertTrue(StyleDeck.autoCandidates(anchors: [], brief: brief).styles.contains(.earthy))
    }
}
