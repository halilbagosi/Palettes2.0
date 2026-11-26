//
//  PaletteStyleBuilderTests.swift
//  PalettesTests
//
//  Styled builds: every interface style stays readable and fills its
//  roles, and every Auto treatment builds what it promises. Fixed seeds
//  make every run identical.
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteStyleBuilderTests: XCTestCase {

    /// Coral, deep blue, grey, pale yellow, and no color of the user's at all.
    private let anchorSets: [[String]] = [["#FF5E7A"], ["#3060A0"], ["#808080"], ["#FFF2A0"], []]
    private let lightStyles = PaletteStyle.deck(for: .uiLight)
    private let darkStyles = PaletteStyle.deck(for: .uiDark)
    private var interfaceStyles: [PaletteStyle] { lightStyles + darkStyles }

    private func mode(of style: PaletteStyle) -> HarmonyScheme {
        if lightStyles.contains(style) { return .uiLight }
        if darkStyles.contains(style) { return .uiDark }
        return .auto
    }

    private func build(_ anchors: [String], size: Int, style: PaletteStyle, tone: PaletteTone = .balanced, seed: UInt64 = 1) -> BuiltPalette {
        PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: mode(of: style), tone: tone, hue: 200, seed: seed, style: style))
    }

    private func hex(_ palette: BuiltPalette, _ role: String) -> String? {
        zip(palette.roles, palette.hexes).first { $0.0 == role }?.1
    }

    private func luminance(_ hex: String) -> Double {
        let c = OKLCH(hex: hex)!.linearSRGB()
        return 0.2126 * max(0, c.r) + 0.7152 * max(0, c.g) + 0.0722 * max(0, c.b)
    }

    private func contrast(_ a: String, _ b: String) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    // MARK: - Interface styles

    func testInterfaceStylesKeepTextReadable() throws {
        for style in interfaceStyles {
            for anchors in anchorSets {
                for size in [6, 8, 12] {
                    for seed: UInt64 in 0..<4 {
                        let palette = build(anchors, size: size, style: style, seed: seed)
                        let label = "\(style) \(anchors) size \(size) seed \(seed)"
                        let background = try XCTUnwrap(hex(palette, "Background"), label)
                        let text = try XCTUnwrap(hex(palette, "Text"), label)
                        let muted = try XCTUnwrap(hex(palette, "Muted Text"), label)
                        XCTAssertGreaterThanOrEqual(contrast(text, background), 4.5, label)
                        XCTAssertGreaterThanOrEqual(contrast(muted, background), 3.0, label)
                    }
                }
            }
        }
    }

    func testInterfaceStylesFillEveryRoleWithDistinctColors() {
        let allRoles = Set(PaletteStyle.interfaceRoleNames + ["Success", "Warning", "Error"])
        for style in interfaceStyles {
            for anchors in anchorSets {
                let palette = build(anchors, size: 12, style: style)
                XCTAssertEqual(palette.hexes.count, 12, "\(style) \(anchors)")
                XCTAssertEqual(Set(palette.hexes).count, 12, "repeated color in \(style) \(anchors): \(palette.hexes)")
                XCTAssertEqual(Set(palette.roles), allRoles, "\(style) \(anchors)")
            }
        }
    }

    func testInterfaceStylesKeepTheUsersColorAsPrimary() {
        for style in interfaceStyles {
            let palette = build(["#3060A0"], size: 8, style: style)
            XCTAssertEqual(palette.hexes.first, "#3060A0", "\(style)")
            XCTAssertEqual(palette.roles.first, "Primary", "\(style)")
        }
    }

    func testOLEDBlackAndHighContrastReachTheEnds() {
        XCTAssertEqual(hex(build([], size: 8, style: .oledBlack), "Background"), "#000000")
        XCTAssertEqual(hex(build([], size: 8, style: .highContrast), "Background"), "#FFFFFF")
    }

    func testStylesInADeckLookDifferent() {
        for deck in [lightStyles, darkStyles] {
            let palettes = deck.map { build(["#3060A0"], size: 8, style: $0).hexes }
            XCTAssertEqual(Set(palettes).count, deck.count)
            let backgrounds = deck.compactMap { hex(build(["#3060A0"], size: 8, style: $0), "Background") }
            XCTAssertEqual(Set(backgrounds).count, deck.count, "backgrounds: \(backgrounds)")
        }
    }

    func testSameStyleAndSeedBuildTheSamePalette() {
        for style in PaletteStyle.allCases {
            XCTAssertEqual(build(["#3060A0"], size: 8, style: style, seed: 9), build(["#3060A0"], size: 8, style: style, seed: 9), "\(style)")
        }
    }

    /// The seed only moves a style a little: its neutrals hold their place.
    func testSeedsKeepAStylesCharacter() throws {
        for style in interfaceStyles {
            let lightness = try (UInt64(0)..<10).map { seed -> Double in
                let background = try XCTUnwrap(hex(build(["#3060A0"], size: 8, style: style, seed: seed), "Background"))
                return OKLCH(hex: background)!.L
            }
            XCTAssertLessThanOrEqual(lightness.max()! - lightness.min()!, 0.035, "\(style): \(lightness)")
        }
    }

    func testGreyPrimaryKeepsFixedHueStylesAndGreysTheRest() throws {
        let warm = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .warmEditorial), "Background"))
        XCTAssertGreaterThan(OKLCH(hex: warm)!.C, 0.012, "Warm Editorial's paper keeps its hue")
        let tonal = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .tonal), "Background"))
        XCTAssertLessThan(OKLCH(hex: tonal)!.C, 0.004, "a grey has no hue to tint with")
        let accent = try XCTUnwrap(hex(build(["#808080"], size: 8, style: .tonal), "Accent"))
        XCTAssertGreaterThan(OKLCH(hex: accent)!.C, 0.05, "colored roles stay colored")
    }

    // MARK: - Auto treatments

    private func generated(_ palette: BuiltPalette) -> [OKLCH] {
        palette.entries.filter { $0.group != .anchor }.compactMap { OKLCH(hex: $0.hex) }
    }

    func testTreatmentsBuildTheirHarmony() {
        let expected: [PaletteStyle: HarmonyScheme] = [
            .analogous603010: .analogous, .complementaryPop: .complementary, .monochromePop: .monochromatic,
            .splitComplementary: .splitComplementary, .triadicPlayful: .triadic,
        ]
        for (style, harmony) in expected {
            for seed: UInt64 in 0..<5 {
                XCTAssertEqual(build([], size: 6, style: style, seed: seed).scheme, harmony, "\(style) seed \(seed)")
            }
        }
    }

    func testSeededTreatmentsStayInTheirHarmonies() {
        for style in [PaletteStyle.pastel, .jewelTones, .earthy] {
            let allowed = Set(style.treatment!.harmonies)
            let built = Set((UInt64(0)..<20).map { build(["#3060A0"], size: 6, style: style, seed: $0).scheme })
            XCTAssertTrue(built.isSubset(of: allowed), "\(style): \(built)")
            XCTAssertEqual(built.count, allowed.count, "\(style) should reach each of its harmonies over 20 seeds")
        }
    }

    func testUsersColorsOutrankTheTreatmentsHarmony() {
        // Blue and orange sit 143° apart: triadic, whatever the treatment says.
        XCTAssertEqual(build(["#3366CC", "#CC6633"], size: 6, style: .pastel).scheme, .triadic)
        XCTAssertEqual(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#3366CC")!, OKLCH(hex: "#CC6633")!]), .triadic)
        XCTAssertEqual(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#808080")!]), .monochromatic)
        XCTAssertNil(PaletteBuilder.impliedHarmony(of: [OKLCH(hex: "#3060A0")!]))
    }

    func testASingleHarmonyStyleKeepsItsHarmonyOverTheUsersColors() throws {
        // Two chromatic colors 30° apart imply analogous.
        let blue = try XCTUnwrap(OKLCH(hex: "#3060A0"))
        let violet = OKLCH(L: 0.55, C: 0.12, h: blue.h + 30).gamutMapped().hex
        let anchors = ["#3060A0", violet]
        XCTAssertEqual(PaletteBuilder.impliedHarmony(of: anchors.compactMap { OKLCH(hex: $0) }), .analogous)
        let expected: [PaletteStyle: HarmonyScheme] = [.triadicPlayful: .triadic, .complementaryPop: .complementary, .monochromePop: .monochromatic]
        for (style, harmony) in expected {
            for seed: UInt64 in 0..<5 {
                let palette = build(anchors, size: 8, style: style, seed: seed)
                XCTAssertEqual(palette.scheme, harmony, "\(style) seed \(seed)")
                XCTAssertEqual(Array(palette.hexes.prefix(2)), anchors, "\(style) seed \(seed)")
                XCTAssertEqual(Set(palette.hexes).count, 8, "\(style) seed \(seed)")
            }
        }
        // The triadic build's generated colors reach the triad's hues (120° and 240° from the first color).
        let generated = generated(build(anchors, size: 8, style: .triadicPlayful)).filter { $0.C >= 0.03 }
        for offset in [120.0, 240] {
            XCTAssertTrue(generated.contains { OKLCH.hueDistance($0.h, blue.h + offset) <= 25 }, "no color near \(offset)° from the first")
        }
        // Treatments with several harmonies still follow the user's colors.
        for style in [PaletteStyle.pastel, .jewelTones, .earthy] {
            XCTAssertEqual(build(anchors, size: 8, style: style).scheme, .analogous, "\(style)")
        }
    }

    func testAPinnedHarmonyOnAGreyCountsFromTheFreeHue() {
        // A grey's own hue angle means nothing: the secondary tones sit at the
        // free hue + 120 / 240, so another hue moves them.
        func secondaryHues(hue: Double, seed: UInt64) -> [Double] {
            let palette = PaletteBuilder.build(PaletteBuildRequest(anchors: ["#808080"], size: 8, scheme: .auto, hue: hue, seed: seed, style: .triadicPlayful))
            XCTAssertEqual(palette.scheme, .triadic)
            XCTAssertEqual(palette.hexes.first, "#808080")
            XCTAssertEqual(Set(palette.hexes).count, 8)
            return palette.entries.filter { $0.group == .secondary }.compactMap { OKLCH(hex: $0.hex) }.filter { $0.C >= 0.03 }.map(\.h)
        }
        for (hue, seed) in [(30.0, UInt64(1)), (200, 2), (320, 3)] {
            let hues = secondaryHues(hue: hue, seed: seed)
            XCTAssertFalse(hues.isEmpty, "hue \(hue)")
            for h in hues {
                XCTAssertTrue([120.0, 240].contains { OKLCH.hueDistance(h, hue + $0) <= 25 }, "hue \(hue): secondary \(h)")
            }
        }
    }

    func testEveryTreatmentKeepsEveryPairDistinct() {
        // No colors, one chromatic, one pale, two chromatic, one grey. A grey
        // is lightness alone: twelve of them cannot all sit 6 apart.
        let sets: [[String]] = [[], ["#FF5E7A"], ["#FFF2A0"], ["#FF5E7A", "#3060A0"], ["#808080"]]
        // The seeds take turns through balanced, light and vivid tones.
        let tones: [PaletteTone] = [.balanced, PaletteTone(lightness: .light), PaletteTone(chroma: .vivid)]
        for style in PaletteStyle.deck(for: .auto) {
            for anchors in sets {
                for size in anchors == ["#808080"] ? [4, 8] : [4, 8, 12] {
                    for seed: UInt64 in 0..<50 {
                        let tone = tones[Int(seed) % tones.count]
                        let hexes = build(anchors, size: size, style: style, tone: tone, seed: seed).hexes
                        var worst = Double.greatestFiniteMagnitude
                        for i in hexes.indices {
                            for j in hexes.indices where j > i {
                                worst = min(worst, ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j]))
                            }
                        }
                        XCTAssertGreaterThanOrEqual(worst, 6, "\(style) \(anchors) size \(size) seed \(seed) tone \(tone): \(hexes)")
                    }
                }
            }
        }
    }

    func testEveryTreatmentReachesItsSizeWithoutRepeats() {
        for style in PaletteStyle.deck(for: .auto) {
            for anchors in anchorSets + [["#3366CC", "#CC6633"]] {
                for size in [4, 8, 12] {
                    let hexes = build(anchors, size: size, style: style).hexes
                    XCTAssertEqual(hexes.count, size, "\(style) \(anchors) size \(size)")
                    XCTAssertEqual(Set(hexes).count, size, "repeated color in \(style): \(hexes)")
                }
            }
        }
    }

    func testComplementaryPopHasNoSecondaryTonesAndOneAccent() {
        for size in [6, 8] {
            let palette = build(["#3060A0"], size: size, style: .complementaryPop)
            XCTAssertTrue(palette.entries.filter { $0.group == .secondary }.isEmpty, "size \(size)")
            XCTAssertEqual(palette.entries.filter { $0.group == .accent }.count, 1, "size \(size)")
        }
    }

    func testMonochromePopAddsOneAccentOffTheMainHue() throws {
        let palette = build(["#3060A0"], size: 6, style: .monochromePop)
        XCTAssertEqual(palette.scheme, .monochromatic)
        let accents = palette.entries.filter { $0.group == .accent }
        XCTAssertEqual(accents.count, 1)
        let accent = try XCTUnwrap(OKLCH(hex: accents[0].hex))
        let anchor = try XCTUnwrap(OKLCH(hex: "#3060A0"))
        XCTAssertEqual(OKLCH.hueDistance(accent.h, anchor.h + 150), 0, accuracy: 20)
    }

    func testMonochromePopOnAGreyTakesTheFreeHue() throws {
        // hue: 200 in `build`, so the accent sits near 200 + 150 = 350.
        let palette = build(["#808080"], size: 6, style: .monochromePop)
        let accent = try XCTUnwrap(palette.entries.first { $0.group == .accent }.flatMap { OKLCH(hex: $0.hex) })
        XCTAssertLessThanOrEqual(OKLCH.hueDistance(accent.h, 350), 25)
    }

    func testPastelIsLighterThanJewelTones() {
        // Neutrals (Background, Text) are the same in both, so only the toned colors count.
        func meanL(_ style: PaletteStyle, seed: UInt64) -> Double {
            let colors = build(["#3060A0"], size: 8, style: style, seed: seed).entries
                .filter { $0.group != .anchor && $0.group != .neutral }
                .compactMap { OKLCH(hex: $0.hex)?.L }
            return colors.reduce(0, +) / Double(colors.count)
        }
        let seeds = UInt64(0)..<8
        for seed in seeds {
            XCTAssertGreaterThan(meanL(.pastel, seed: seed), meanL(.jewelTones, seed: seed), "seed \(seed)")
        }
        let pastel = seeds.map { meanL(.pastel, seed: $0) }.reduce(0, +) / Double(seeds.count)
        let jewel = seeds.map { meanL(.jewelTones, seed: $0) }.reduce(0, +) / Double(seeds.count)
        XCTAssertGreaterThan(pastel, jewel + 0.1, "pastel \(pastel) vs jewel \(jewel)")
    }

    func testVibeToneWinsOverTheTreatment() {
        func mean(_ style: PaletteStyle, _ tone: PaletteTone, _ value: (OKLCH) -> Double) -> Double {
            let colors = build(["#3060A0"], size: 8, style: style, tone: tone).entries
                .filter { $0.group != .anchor && $0.group != .neutral }
                .compactMap { OKLCH(hex: $0.hex) }
            return colors.map(value).reduce(0, +) / Double(colors.count)
        }
        // Jewel Tones brings dark; a light vibe wins.
        XCTAssertGreaterThan(mean(.jewelTones, PaletteTone(lightness: .light), \.L), mean(.jewelTones, .balanced, \.L) + 0.1)
        // Pastel brings muted; a vivid vibe wins.
        XCTAssertGreaterThan(mean(.pastel, PaletteTone(chroma: .vivid), \.C), mean(.pastel, .balanced, \.C))
    }

    func testPastelStaysInThePastelBand() {
        for anchors in [[], ["#3060A0"], ["#FF5E7A"]] as [[String]] {
            for seed: UInt64 in 0..<6 {
                let toned = build(anchors, size: 8, style: .pastel, seed: seed).entries
                    .filter { $0.group != .anchor && $0.group != .neutral }
                    .compactMap { OKLCH(hex: $0.hex) }
                XCTAssertFalse(toned.isEmpty)
                for color in toned {
                    XCTAssertGreaterThanOrEqual(color.L, 0.745, "\(anchors) seed \(seed)")
                    XCTAssertLessThanOrEqual(color.L, 0.935, "\(anchors) seed \(seed)")
                }
            }
        }
    }

    func testEarthyLeadSharesItsFamilysHue() throws {
        for seed: UInt64 in 0..<6 {
            let dominant = build([], size: 8, style: .earthy, seed: seed).entries
                .filter { $0.group == .dominant }
                .compactMap { OKLCH(hex: $0.hex) }
            let lead = try XCTUnwrap(dominant.first)
            for color in dominant.dropFirst() where color.C >= 0.02 {
                XCTAssertLessThanOrEqual(OKLCH.hueDistance(color.h, lead.h), 5, "seed \(seed)")
            }
        }
    }

    /// #3060A0 sits at OKLCH hue 256.4. A 25% pull toward 60° moves the hues
    /// 256.4 + {30, -30, 180} (286.4, 226.4, 76.4) to these.
    private let pulledFromBlue: [HarmonyScheme: [Double]] = [.analogous: [319.8, 184.8], .complementary: [72.3]]

    func testEarthyPullsTheAccentTooAndMutesIt() throws {
        for seed: UInt64 in 0..<6 {
            let palette = build(["#3060A0"], size: 8, style: .earthy, seed: seed)
            let accent = try XCTUnwrap(palette.entries.first { $0.group == .accent }.flatMap { OKLCH(hex: $0.hex) }, "seed \(seed)")
            let expected = try XCTUnwrap(pulledFromBlue[palette.scheme], "seed \(seed): \(palette.scheme)")
            XCTAssertTrue(expected.contains { OKLCH.hueDistance(accent.h, $0) <= 6 }, "seed \(seed): accent \(accent.h), expected one of \(expected)")
            XCTAssertLessThanOrEqual(accent.C, 0.16, "seed \(seed)")
        }
    }

    func testMutedVibeTonesDownThePopAccent() throws {
        for style in [PaletteStyle.complementaryPop, .monochromePop] {
            func accentC(_ tone: PaletteTone) throws -> Double {
                try XCTUnwrap(build(["#3060A0"], size: 6, style: style, tone: tone).entries
                    .first { $0.group == .accent }.flatMap { OKLCH(hex: $0.hex)?.C })
            }
            XCTAssertLessThan(try accentC(PaletteTone(chroma: .muted)), try accentC(.balanced), "\(style)")
        }
    }

    func testEarthyKeepsTheUsersColorsFamilyAndPullsTheRest() throws {
        for seed: UInt64 in 0..<6 {
            let palette = build(["#3060A0"], size: 8, style: .earthy, seed: seed)
            let toned = { (group: BuiltPalette.Group) in
                palette.entries.filter { $0.group == group }.compactMap { OKLCH(hex: $0.hex) }.filter { $0.C >= 0.03 }
            }
            // The family around the user's color stays blue.
            let dominant = toned(.dominant)
            XCTAssertFalse(dominant.isEmpty, "seed \(seed)")
            for color in dominant {
                XCTAssertLessThanOrEqual(OKLCH.hueDistance(color.h, 256.4), 10, "seed \(seed): dominant \(color.h)")
            }
            // The other hues sit where the pulled offsets put them.
            let expected = try XCTUnwrap(pulledFromBlue[palette.scheme], "seed \(seed): \(palette.scheme)")
            let others = toned(.secondary) + toned(.accent)
            XCTAssertFalse(others.isEmpty, "seed \(seed)")
            for color in others {
                XCTAssertTrue(expected.contains { OKLCH.hueDistance(color.h, $0) <= 8 }, "seed \(seed): hue \(color.h), expected one of \(expected)")
            }
        }
    }
}
