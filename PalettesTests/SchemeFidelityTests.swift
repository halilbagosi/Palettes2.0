//
//  SchemeFidelityTests.swift
//  PalettesTests
//
//  End-to-end checks that a generated palette keeps the mode the user
//  picked. PaletteBuilderTests pins the builder over fixed seeds; these go
//  through `PaletteGenerator.generate` (the Simulator path, random seed) so
//  the wiring between the two is covered too.
//

import XCTest
@testable import Palettes

@available(iOS 26.0, *)
final class SchemeFidelityTests: XCTestCase {

    private let base = "#3366CC"

    private func generate(_ scheme: HarmonyScheme, size: Int, bases: [String]? = nil) async throws -> PaletteViewModel {
        try await PaletteGenerator.generate(
            baseColors: (bases ?? [base]).map { PaletteGenerator.BaseColor(hex: $0, name: "") },
            size: size,
            vibe: nil,
            scheme: scheme
        )
    }

    /// Every clearly colored swatch sits on one of its scheme's hues
    /// (OKLCH; greys and near-blacks skipped, their hue is rounding noise).
    @MainActor
    func testEverySchemeShipsOnlyInFamilyHues() async throws {
        let baseHue = OKLCH(hex: base)!.h
        for scheme in [HarmonyScheme.complementary, .splitComplementary, .analogous, .triadic, .monochromatic] {
            let offsets = [0] + PaletteBuilder.offsets(for: scheme)
            for size in [4, 6, 8, 12] {
                for _ in 0..<3 {
                    let palette = try await generate(scheme, size: size)
                    for hex in palette.hexCodes {
                        let color = OKLCH(hex: hex)!
                        guard color.C >= 0.04, color.L >= 0.2 else { continue }
                        let miss = offsets.map { OKLCH.hueDistance(color.h, baseHue + $0) }.min()!
                        XCTAssertLessThanOrEqual(miss, 5, "\(scheme) size \(size): \(hex) is \(miss)° off — \(palette.hexCodes)")
                    }
                }
            }
        }
    }

    @MainActor
    func testEverySchemeReachesTheRequestedSize() async throws {
        for scheme in HarmonyScheme.allCases {
            for size in [2, 4, 6, 8, 10, 12] {
                let palette = try await generate(scheme, size: size)
                XCTAssertEqual(palette.hexCodes.count, size, "\(scheme) size \(size)")
                XCTAssertEqual(palette.colorNames.count, size)
                XCTAssertEqual(palette.colorRoles.count, size)
                XCTAssertEqual(Set(palette.colorNames).count, size, "names must be unique: \(palette.colorNames)")
            }
        }
    }

    /// Two chosen colors split the generated tones evenly. This used to
    /// fail about one run in seven.
    @MainActor
    func testTwoSelectedBasesShareTheTonesEvenly() async throws {
        let bases = ["#3366CC", "#CC6633"]
        let hues = bases.map { OKLCH(hex: $0)!.h }
        for _ in 0..<10 {
            // Size 8 monochromatic: 2 bases + 4 tones + 2 neutrals (low chroma, skipped).
            let palette = try await generate(.monochromatic, size: 8, bases: bases)
            var shares = [0, 0]
            for hex in palette.hexCodes.dropFirst(2) {
                let color = OKLCH(hex: hex)!
                guard color.C >= 0.03 else { continue }
                shares[OKLCH.hueDistance(color.h, hues[0]) < OKLCH.hueDistance(color.h, hues[1]) ? 0 : 1] += 1
            }
            XCTAssertEqual(shares, [2, 2], "\(palette.hexCodes)")
        }
    }
}
