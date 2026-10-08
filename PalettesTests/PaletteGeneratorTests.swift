//
//  PaletteGeneratorTests.swift
//  PalettesTests
//

import XCTest
import UIKit
import SwiftUI
@testable import Palettes

final class PaletteGeneratorTests: XCTestCase {

    // MARK: - Regression: empty base colors must still fill to size

    /// Regression test for the cold-start bug: with no base colors selected
    /// (the default form state, and what `GeneratePaletteIntent` always
    /// passes), generation must still return a full-size palette. Exercises
    /// the Simulator path the test suite actually runs under.
    /// Generated palettes must not be handed a generic title, and must not
    /// reuse a title already present in the user's library.
    @available(iOS 26.0, *)
    @MainActor
    func testGeneratedPaletteTitleIsSpecificAndNotAlreadyUsed() async throws {
        let base = [PaletteGenerator.BaseColor(hex: "#A9603F", name: "Clay")]
        let first = try await PaletteGenerator.generate(baseColors: base, size: 5, vibe: nil)
        XCTAssertFalse(first.name.isEmpty)
        for generic in ["Generated Palette", "Simulator Palette", "Palette", "Untitled"] {
            XCTAssertNotEqual(first.name.caseInsensitiveCompare(generic), .orderedSame,
                              "got a generic title: \(first.name)")
        }

        // Asking again with that title already taken must yield a different one.
        let second = try await PaletteGenerator.generate(
            baseColors: base, size: 5, vibe: nil, existingNames: [first.name]
        )
        XCTAssertNotEqual(second.name.lowercased(), first.name.lowercased())
    }

    @available(iOS 26.0, *)
    @MainActor
    func testMockGenerateWithNoBaseColorsFillsToRequestedSize() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [],
            size: 6,
            vibe: nil
        )
        XCTAssertEqual(result.colors.count, 6)
        XCTAssertEqual(result.hexCodes.count, 6)
        XCTAssertEqual(result.colorNames.count, 6)
    }

    /// The generation orb must receive the final resolved colors one at a
    /// time. It preserves the arrival animation without streaming provisional
    /// colors that get replaced at reveal time.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerationPreviewMatchesTheFinalPaletteImmediately() async throws {
        var previews: [[String]] = []
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3366CC", name: "Ocean Blue")],
            size: 6,
            vibe: nil,
            scheme: .monochromatic,
            onPartialColors: { colors in
                previews.append(colors.map(ColorAdjustment.hexString(from:)))
            }
        )

        XCTAssertEqual(previews.count, result.hexCodes.count - 1)
        for (offset, preview) in previews.enumerated() {
            XCTAssertEqual(preview, Array(result.hexCodes.prefix(offset + 2)))
        }
    }

    // MARK: - Role assignment on generation (Task 5)

    /// Generating from a single base color should tag it "Primary".
    /// Exercises the Simulator path (the only one reachable from tests).
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateFromOneBaseColorTagsFirstColorPrimary() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue")],
            size: 5,
            vibe: nil
        )
        XCTAssertEqual(result.paletteColors.first?.role, "Primary")
    }

    /// Harmonic palettes of 8 or more get two tinted neutrals tagged
    /// Background and Text, whichever scheme Auto resolves to.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateSizeEightFromSaturatedBaseTagsBackgroundAndText() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue")],
            size: 8,
            vibe: nil
        )
        let roles = Set(result.paletteColors.compactMap(\.role))
        XCTAssertEqual(result.paletteColors.first?.role, "Primary")
        XCTAssertTrue(roles.contains("Background"), "expected a Background role among \(roles)")
        XCTAssertTrue(roles.contains("Text"), "expected a Text role among \(roles)")
    }

    /// With no base colors at all, there's no real anchor for `Primary`/
    /// `Secondary`/etc. to attach to, so every role must stay nil.
    @available(iOS 26.0, *)
    @MainActor
    func testGenerateWithNoBaseColorsYieldsAllNilRoles() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [],
            size: 6,
            vibe: "sunset over the ocean"
        )
        XCTAssertTrue(result.paletteColors.allSatisfy { $0.role == nil })
    }

    // MARK: - Perceptual distinctness

    /// No two colors in a generated palette read as the same: every pair
    /// is at least CIEDE2000 6 apart (palettes of up to 8 colors; only long
    /// monochromatic palettes may sit closer).
    @available(iOS 26.0, *)
    @MainActor
    func testGeneratedPaletteOfEightKeepsEveryPairDistinct() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 8, vibe: nil)
        let hexes = result.hexCodes
        XCTAssertEqual(hexes.count, 8)
        for i in hexes.indices {
            for j in hexes.indices where j > i {
                let distance = ColorNamer.perceptualDistance(hex1: hexes[i], hex2: hexes[j])
                XCTAssertGreaterThanOrEqual(distance, 6, "\(hexes[i]) and \(hexes[j]) are only ΔE \(distance) apart")
            }
        }
    }

    /// Locked (user-chosen) base colors are exempt from the perceptual gate
    /// against EACH OTHER — two similar locked colors must both still appear
    /// verbatim. Only non-locked candidates are gated.
    @available(iOS 26.0, *)
    @MainActor
    func testLockedColorsAreExemptFromPerceptualGateAgainstEachOther() async throws {
        // Two near-identical locked blues (ΔE well under 12 from each other).
        let result = try await PaletteGenerator.generate(
            baseColors: [
                PaletteGenerator.BaseColor(hex: "#3060A0", name: "Ocean Blue"),
                PaletteGenerator.BaseColor(hex: "#3161A1", name: "Ocean Blue Two"),
            ],
            size: 4,
            vibe: nil
        )
        XCTAssertTrue(result.hexCodes.contains("#3060A0"))
        XCTAssertTrue(result.hexCodes.contains("#3161A1"))
    }

    /// An image-sourced palette (all colors locked, no vibe, size == the
    /// number of colors supplied) must contain EXACTLY those colors — the
    /// generator must synthesize nothing to "reach" a larger size. This is
    /// the invariant `GenerateView` relies on to keep image palettes free of
    /// colors that aren't in the image.
    @available(iOS 26.0, *)
    @MainActor
    func testLockedColorsWithMatchingSizeAddNoSynthesizedColors() async throws {
        let locked = [
            PaletteGenerator.BaseColor(hex: "#2E4756", name: "A"),
            PaletteGenerator.BaseColor(hex: "#C9A15A", name: "B"),
            PaletteGenerator.BaseColor(hex: "#8B4A3F", name: "C"),
            PaletteGenerator.BaseColor(hex: "#6E8B5A", name: "D"),
            PaletteGenerator.BaseColor(hex: "#D8C7B0", name: "E"),
        ]
        let result = try await PaletteGenerator.generate(
            baseColors: locked,
            size: locked.count,
            vibe: nil
        )
        XCTAssertEqual(result.hexCodes.count, locked.count)
        XCTAssertEqual(Set(result.hexCodes), Set(locked.map { $0.hex }),
                       "palette must contain only the supplied colors, none synthesized")
    }

    // MARK: - Brief, modes and names

    @available(iOS 26.0, *)
    @MainActor
    func testVibeColorWordSetsTheMainHue() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 6, vibe: "navy evening", scheme: .analogous)
        let main = OKLCH(hex: result.hexCodes[0])!
        XCTAssertLessThanOrEqual(OKLCH.hueDistance(main.h, 262), 5, "\(result.hexCodes)")
    }

    /// A mode chosen alongside a vibe (no colors selected) shapes the palette.
    @available(iOS 26.0, *)
    @MainActor
    func testChosenModeAppliesToAVibeOnlyPalette() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 6, vibe: "warm autumn forest", scheme: .monochromatic)
        let hue = OKLCH(hex: result.hexCodes[0])!.h
        for hex in result.hexCodes {
            let color = OKLCH(hex: hex)!
            guard color.C >= 0.04, color.L >= 0.2 else { continue }
            XCTAssertLessThanOrEqual(OKLCH.hueDistance(color.h, hue), 5, "\(hex) in \(result.hexCodes)")
        }
    }

    @available(iOS 26.0, *)
    @MainActor
    func testInterfaceModeWithAVibeCarriesItsRoles() async throws {
        let result = try await PaletteGenerator.generate(baseColors: [], size: 4, vibe: "calm ocean", scheme: .uiLight)
        XCTAssertEqual(result.paletteColors.map(\.role), ["Primary", "Background", "Text", "Accent"])
    }

    /// The model's names are matched by list number, never by position, and
    /// only ship when they fit their swatch.
    @available(iOS 26.0, *)
    func testModelNamesAreMatchedByNumberAndChecked() {
        let hexes = ["#2F6BD8", "#E2683C", "#F1F5FD", "#3E8E5E"]
        let accepted = PaletteGenerator.acceptedNames(
            [
                (number: 4, name: "Fern"),           // out of order: still lands on #3E8E5E
                (number: 2, name: "Blue Lagoon"),    // a blue name on an orange: rejected
                (number: 3, name: "Morning Frost"),  // fits a near-white
                (number: 1, name: "Harbor"),         // color 1 is the user's, already named
                (number: 9, name: "Nowhere"),        // there is no color 9
                (number: 2, name: "Fern"),           // a repeat: rejected
            ],
            hexes: hexes,
            unnamed: [1, 2, 3]
        )
        XCTAssertEqual(accepted, [3: "Fern", 2: "Morning Frost"])
    }

    /// A base color the builder can't use (short or alpha hex) must not
    /// count toward the palette: the result still reaches the requested size.
    @available(iOS 26.0, *)
    @MainActor
    func testUnusableBaseHexDoesNotShrinkThePalette() async throws {
        let result = try await PaletteGenerator.generate(
            baseColors: [
                PaletteGenerator.BaseColor(hex: "#ABC", name: "Short"),
                PaletteGenerator.BaseColor(hex: "#3366CC", name: "Ocean Blue"),
            ],
            size: 4,
            vibe: nil
        )
        XCTAssertEqual(result.hexCodes.count, 4)
        XCTAssertEqual(result.hexCodes.first, "#3366CC")
        XCTAssertEqual(result.colorNames.first, "Ocean Blue")
    }
}
