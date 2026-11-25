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
        for seed: UInt64 in 0..<4 {
            func meanL(_ style: PaletteStyle) -> Double {
                let colors = generated(build(["#3060A0"], size: 8, style: style, seed: seed))
                return colors.map(\.L).reduce(0, +) / Double(colors.count)
            }
            XCTAssertGreaterThan(meanL(.pastel), meanL(.jewelTones) + 0.15, "seed \(seed)")
        }
    }

    func testVibeToneWinsOverTheTreatment() {
        func meanL(_ tone: PaletteTone) -> Double {
            let colors = generated(build(["#3060A0"], size: 8, style: .pastel, tone: tone))
            return colors.map(\.L).reduce(0, +) / Double(colors.count)
        }
        XCTAssertLessThan(meanL(PaletteTone(lightness: .dark)), meanL(.balanced) - 0.1)
    }

    func testEarthyPullsHuesTowardEarth() throws {
        let anchor = try XCTUnwrap(OKLCH(hex: "#3060A0"))
        let dominant = build(["#3060A0"], size: 8, style: .earthy).entries
            .filter { $0.group == .dominant }
            .compactMap { OKLCH(hex: $0.hex) }
            .filter { $0.C >= 0.02 }
        XCTAssertFalse(dominant.isEmpty)
        for color in dominant {
            // A 25% pull moves blue (~262°) about 40° toward 60°; allow for hue rounding at low chroma.
            XCTAssertLessThan(OKLCH.hueDistance(color.h, 60), OKLCH.hueDistance(anchor.h, 60) - 20)
        }
    }
}
