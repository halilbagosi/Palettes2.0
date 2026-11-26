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
        ]
        for (hex, expected) in cases {
            let color = OKLCH(hex: hex)!
            XCTAssertEqual(PaletteStyle.ranked(auto, for: color).first, expected, "\(hex) L \(color.L) C \(color.C) h \(color.h)")
        }
    }

    func testRankingKeepsEveryStyleAndBreaksTiesByDeckOrder() {
        let ranked = PaletteStyle.ranked(auto, for: OKLCH(hex: "#3060A0")!)
        XCTAssertEqual(Set(ranked), Set(auto))
        XCTAssertEqual(ranked.count, auto.count)
        // Equal fits keep their deck order: Monochrome + Pop and Pastel never outrank the calm default for a mid blue.
        XCTAssertLessThan(ranked.firstIndex(of: .analogous603010)!, ranked.firstIndex(of: .monochromePop)!)
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
}
