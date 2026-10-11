//
//  PaletteBuilderTests.swift
//  PalettesTests
//
//  The builder makes every color a generated palette ships, so these tests
//  pin its promises directly over fixed seeds: exact size, the user's
//  colors first and verbatim, hues on the scheme's offsets, colors that
//  read as different, even shares for several chosen colors, and the
//  interface roles. Fixed seeds make every run identical.
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteBuilderTests: XCTestCase {

    private let harmonicSchemes: [HarmonyScheme] = [.complementary, .splitComplementary, .analogous, .triadic, .monochromatic]
    /// Single colors around the wheel, plus no anchor at all (hue 200).
    private let anchorSets: [[String]] = [["#3366CC"], ["#3E8E5E"], ["#E2683C"], []]
    private let seeds: [UInt64] = [0, 1, 2, 3, 4, 5]

    private func build(
        _ anchors: [String],
        size: Int,
        scheme: HarmonyScheme,
        tone: PaletteTone? = nil,
        seed: UInt64
    ) -> BuiltPalette {
        PaletteBuilder.build(PaletteBuildRequest(anchors: anchors, size: size, scheme: scheme, tone: tone ?? .balanced, hue: 200, seed: seed))
    }

    // MARK: - Structure

    func testGroupCountsFollowSixtyThirtyTen() {
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 2, scheme: .complementary), .init(dominant: 1, secondary: 1, accent: 0, neutral: 0))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 4, scheme: .complementary), .init(dominant: 2, secondary: 1, accent: 1, neutral: 0))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 6, scheme: .triadic), .init(dominant: 3, secondary: 1, accent: 1, neutral: 1))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 12, scheme: .analogous), .init(dominant: 6, secondary: 3, accent: 1, neutral: 2))
        XCTAssertEqual(PaletteBuilder.groupCounts(size: 8, scheme: .monochromatic), .init(dominant: 6, secondary: 0, accent: 0, neutral: 2))
    }

    func testEveryRequestReachesItsSizeWithoutRepeats() {
        for scheme in HarmonyScheme.allCases {
            for anchors in anchorSets + [["#3366CC", "#CC6633"]] {
                for size in [2, 3, 4, 6, 8, 10, 12] {
                    for seed in seeds.prefix(3) {
                        let hexes = build(anchors, size: size, scheme: scheme, seed: seed).hexes
                        XCTAssertEqual(hexes.count, size, "\(scheme) \(anchors) size \(size) seed \(seed)")
                        XCTAssertEqual(Set(hexes).count, hexes.count, "repeated color: \(hexes)")
                    }
                }
            }
        }
    }

    func testAnchorsShipFirstAndVerbatim() {
        let palette = build(["3366cc", "#CC6633", "#3366CC"], size: 6, scheme: .complementary, seed: 1)
        XCTAssertEqual(Array(palette.hexes.prefix(2)), ["#3366CC", "#CC6633"])
        XCTAssertEqual(Array(palette.roles.prefix(2)), ["Primary", "Secondary"])
        XCTAssertEqual(palette.entries.filter { $0.group == .anchor }.count, 2)
    }

    func testAnchorsAloneWhenTheyFillTheSize() {
        let anchors = ["#2E4756", "#C9A15A", "#8B4A3F"]
        XCTAssertEqual(build(anchors, size: 2, scheme: .auto, seed: 1).hexes, anchors)
    }

    // MARK: - Hue fidelity

    /// Every clearly colored swatch sits on one of its scheme's hues,
    /// measured in OKLCH, the space the builder works in. Greys and
    /// near-blacks are skipped: their hue angle is rounding noise.
    func testEverySchemeStaysOnItsHues() {
        for scheme in harmonicSchemes {
            let offsets = [0] + PaletteBuilder.offsets(for: scheme)
            for anchors in anchorSets {
                let rootHue = anchors.first.flatMap { OKLCH(hex: $0)?.h } ?? 200
                for size in [4, 6, 8, 12] {
                    for seed in seeds {
                        let palette = build(anchors, size: size, scheme: scheme, seed: seed)
                        for hex in palette.hexes {
                            let color = OKLCH(hex: hex)!
                            guard color.C >= 0.04, color.L >= 0.2 else { continue }
                            let miss = offsets.map { OKLCH.hueDistance(color.h, rootHue + $0) }.min()!
                            XCTAssertLessThanOrEqual(miss, 5, "\(scheme) \(anchors) size \(size) seed \(seed): \(hex) is \(miss)° off — \(palette.hexes)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Distinctness

    /// Small palettes clear the full CIEDE2000 floor of 12; larger ones may
    /// step down to 6 (still a visible step) rather than leave the family.
    func testGeneratedColorsReadAsDifferent() {
        for scheme in harmonicSchemes {
            for anchors in anchorSets {
                for size in [2, 4, 6, 8] {
                    for seed in seeds {
                        let hexes = build(anchors, size: size, scheme: scheme, seed: seed).hexes
                        let floor: Double = size <= 4 ? 12 : 6
                        for i in hexes.indices {
                            for j in hexes.indices where j > i && j >= anchors.count {
                                let distance = ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j])
                                XCTAssertGreaterThanOrEqual(distance, floor, "\(scheme) size \(size) seed \(seed): \(hexes[i]) vs \(hexes[j])")
                            }
                        }
                    }
                }
            }
        }
    }

    /// Two chosen colors split the generated tones evenly. The old HSB
    /// planner refilled a rejected tone from the other color, so this came
    /// out [2, 4] about one run in seven.
    func testTwoAnchorsShareTheTonesEvenly() {
        let anchors = ["#3366CC", "#CC6633"]
        let hues = anchors.map { OKLCH(hex: $0)!.h }
        for seed in UInt64(0)..<20 {
            let palette = build(anchors, size: 8, scheme: .monochromatic, seed: seed)
            var shares = [0, 0]
            for entry in palette.entries where entry.group == .dominant {
                let hue = OKLCH(hex: entry.hex)!.h
                shares[OKLCH.hueDistance(hue, hues[0]) < OKLCH.hueDistance(hue, hues[1]) ? 0 : 1] += 1
            }
            XCTAssertEqual(shares, [2, 2], "seed \(seed): \(palette.hexes)")
        }
    }

    // MARK: - Tone

    func testBalancedPalettesSpanLightAndDark() {
        for scheme in harmonicSchemes {
            for anchors in anchorSets {
                for size in [4, 6, 8] {
                    for seed in seeds {
                        let lightness = build(anchors, size: size, scheme: scheme, seed: seed).hexes.map { OKLCH(hex: $0)!.L }
                        XCTAssertGreaterThanOrEqual(lightness.max()! - lightness.min()!, 0.2, "\(scheme) \(anchors) size \(size) seed \(seed)")
                    }
                }
            }
        }
    }

    func testToneMovesTheMainColor() {
        func mainLightness(_ lightness: PaletteTone.Lightness) -> Double {
            OKLCH(hex: build([], size: 6, scheme: .analogous, tone: PaletteTone(lightness: lightness), seed: 1).hexes[0])!.L
        }
        XCTAssertLessThan(mainLightness(.dark) + 0.1, mainLightness(.balanced))
        XCTAssertLessThan(mainLightness(.balanced) + 0.1, mainLightness(.light))
    }

    func testMutedToneLowersChroma() {
        func meanChroma(_ chroma: PaletteTone.Chroma) -> Double {
            let generated = build(["#3366CC"], size: 6, scheme: .analogous, tone: PaletteTone(chroma: chroma), seed: 1).hexes.dropFirst()
            return generated.map { OKLCH(hex: $0)!.C }.reduce(0, +) / Double(generated.count)
        }
        XCTAssertLessThan(meanChroma(.muted), meanChroma(.balanced))
    }

    // MARK: - Auto

    func testAutoReadsTheRelationshipBetweenTwoAnchors() {
        // Blue (262°) and orange (45°) sit 143° apart: nearest to triadic.
        XCTAssertEqual(build(["#3366CC", "#CC6633"], size: 6, scheme: .auto, seed: 1).scheme, .triadic)
        XCTAssertEqual(build(["#3366CC", "#4D7FE0"], size: 6, scheme: .auto, seed: 1).scheme, .analogous)
    }

    func testAutoOnAGreyIsMonochromatic() {
        XCTAssertEqual(build(["#808080"], size: 6, scheme: .auto, seed: 1).scheme, .monochromatic)
    }

    /// The old Auto always picked split-complementary for one color at
    /// size 5 and up. It now varies with the seed.
    func testAutoVariesForASingleColor() {
        let schemes = Set((UInt64(0)..<40).map { build(["#3366CC"], size: 6, scheme: .auto, seed: $0).scheme })
        XCTAssertGreaterThanOrEqual(schemes.count, 4)
        XCTAssertFalse(schemes.contains(.auto))
        XCTAssertFalse(schemes.contains { $0.isUIMode })
    }

    // MARK: - Roles

    func testHarmonicPalettesWithoutAnchorsHaveNoRoles() {
        for scheme in harmonicSchemes {
            XCTAssertTrue(build([], size: 8, scheme: scheme, seed: 1).roles.allSatisfy(\.isEmpty), "\(scheme)")
        }
    }

    func testNeutralsCarryBackgroundAndText() {
        let roles = build(["#3060A0"], size: 8, scheme: .complementary, seed: 1).roles
        XCTAssertEqual(roles.first, "Primary")
        XCTAssertTrue(roles.contains("Accent"))
        XCTAssertTrue(roles.contains("Background"))
        XCTAssertTrue(roles.contains("Text"))
    }

    func testInterfaceModesFillTheirRolesInOrder() {
        let light = build([], size: 4, scheme: .uiLight, seed: 1)
        XCTAssertEqual(light.roles, ["Primary", "Background", "Text", "Accent"])
        XCTAssertGreaterThan(OKLCH(hex: light.hexes[1])!.L, 0.95)
        XCTAssertLessThan(OKLCH(hex: light.hexes[2])!.L, 0.3)

        let dark = build([], size: 4, scheme: .uiDark, seed: 1)
        XCTAssertEqual(dark.roles, ["Primary", "Background", "Text", "Accent"])
        XCTAssertLessThan(OKLCH(hex: dark.hexes[1])!.L, 0.25)
        XCTAssertGreaterThan(OKLCH(hex: dark.hexes[2])!.L, 0.9)
    }

    func testInterfaceModeKeepsTheUsersColorAsPrimary() {
        let palette = build(["#3060A0"], size: 5, scheme: .uiLight, seed: 1)
        XCTAssertEqual(palette.hexes.first, "#3060A0")
        XCTAssertEqual(palette.roles, ["Primary", "Background", "Text", "Accent", "Surface"])
    }

    // MARK: - Determinism

    func testSameRequestBuildsTheSamePalette() {
        for scheme in HarmonyScheme.allCases {
            XCTAssertEqual(build(["#3366CC"], size: 8, scheme: scheme, seed: 9), build(["#3366CC"], size: 8, scheme: scheme, seed: 9))
        }
        let differing = [4, 6, 8].filter {
            build(["#3366CC"], size: $0, scheme: .complementary, seed: 1).hexes
                != build(["#3366CC"], size: $0, scheme: .complementary, seed: 2).hexes
        }
        XCTAssertFalse(differing.isEmpty, "the seed should vary the palette")
    }
}
