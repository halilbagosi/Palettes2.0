//
//  PaletteNamerTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class PaletteNamerTests: XCTestCase {

    // MARK: - Descriptive naming

    /// A warm, muted, earthy palette should describe itself with a warm
    /// character word and an earthy family — not a generic title.
    func testWarmMutedPaletteGetsWarmDescriptiveName() {
        let name = PaletteNamer.descriptiveName(
            forHexes: ["#A9603F", "#C08552", "#8C5A3B", "#D9A574"],
            existingNames: []
        )
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.contains("Generated"), "must not fall back to a generic title: \(name)")
        // Two-or-three word title, each word capitalized.
        let words = name.split(separator: " ")
        XCTAssertTrue((2...3).contains(words.count), "expected 2-3 words, got \(name)")
        for word in words {
            XCTAssertTrue(word.first!.isUppercase, "each word should be capitalized: \(name)")
        }
    }

    /// Palettes with genuinely different color content must not collide on a
    /// name — this is the core "they all get named the same" complaint.
    func testDifferentPalettesGetDifferentNames() {
        let palettes: [[String]] = [
            ["#A9603F", "#C08552", "#8C5A3B"],   // warm earth
            ["#2E5F8A", "#3E7FB0", "#1E3F5A"],   // cool blue
            ["#4E7A4F", "#6FA36F", "#2F4F2F"],   // green
            ["#6B4E8A", "#8E6FB0", "#4A2F5F"],   // purple
            ["#E8E2D8", "#D8D2C8", "#F0EBE2"],   // pale neutral
        ]
        var names: [String] = []
        for hexes in palettes {
            names.append(PaletteNamer.descriptiveName(forHexes: hexes, existingNames: names))
        }
        XCTAssertEqual(Set(names).count, names.count, "names collided: \(names)")
    }

    /// Deterministic: the same palette always yields the same name.
    func testDescriptiveNamingIsDeterministic() {
        let hexes = ["#2E5F8A", "#3E7FB0", "#1E3F5A", "#D9A574"]
        let a = PaletteNamer.descriptiveName(forHexes: hexes, existingNames: [])
        let b = PaletteNamer.descriptiveName(forHexes: hexes, existingNames: [])
        XCTAssertEqual(a, b)
    }

    /// A name already used in the library must be avoided (case-insensitively).
    func testAvoidsNamesAlreadyInUse() {
        let hexes = ["#A9603F", "#C08552", "#8C5A3B"]
        let first = PaletteNamer.descriptiveName(forHexes: hexes, existingNames: [])
        let second = PaletteNamer.descriptiveName(forHexes: hexes, existingNames: [first.lowercased()])
        XCTAssertNotEqual(second.lowercased(), first.lowercased())
        XCTAssertFalse(second.isEmpty)
    }

    /// Empty input must still produce a usable, non-empty title.
    func testEmptyPaletteStillYieldsAName() {
        let name = PaletteNamer.descriptiveName(forHexes: [], existingNames: [])
        XCTAssertFalse(name.isEmpty)
    }

    // MARK: - Resolving the AI's name

    /// A good AI name is honored verbatim.
    func testGoodAINameIsKept() {
        let name = PaletteNamer.resolvedName(
            aiName: "Harbor Dusk",
            hexes: ["#2E5F8A", "#3E7FB0"],
            existingNames: []
        )
        XCTAssertEqual(name, "Harbor Dusk")
    }

    /// Generic AI names are rejected in favor of a descriptive one.
    func testGenericAINamesAreReplaced() {
        for generic in ["Generated Palette", "palette", "Color Palette", "My Palette", "Untitled", "  ", "Colors"] {
            let name = PaletteNamer.resolvedName(
                aiName: generic,
                hexes: ["#A9603F", "#C08552", "#8C5A3B"],
                existingNames: []
            )
            XCTAssertFalse(
                name.trimmingCharacters(in: .whitespaces).caseInsensitiveCompare(generic.trimmingCharacters(in: .whitespaces)) == .orderedSame,
                "generic name '\(generic)' should have been replaced, got '\(name)'"
            )
            XCTAssertFalse(name.isEmpty)
        }
    }

    /// Common model clichés should not repeatedly become palette titles. They
    /// are less descriptive than the color-derived fallback and were showing
    /// up disproportionately often in generated palettes.
    func testClichedAINameIsReplaced() {
        let hexes = ["#2E5F8A", "#3E7FB0", "#1E3F5A"]
        for cliché in ["Whispering Horizon", "Blue Harmony", "Serene Dream"] {
            let name = PaletteNamer.resolvedName(aiName: cliché, hexes: hexes, existingNames: [])
            XCTAssertNotEqual(name.lowercased(), cliché.lowercased())
            XCTAssertFalse(name.lowercased().contains("whisper"))
            XCTAssertFalse(name.lowercased().contains("horizon"))
            XCTAssertFalse(name.lowercased().contains("harmony"))
        }
    }

    /// Close palettes should still get varied first-choice titles even when a
    /// caller has not yet supplied the library's existing names.
    func testSimilarPalettesVaryTheirDescriptiveTitles() {
        let palettes = [
            ["#2E5F8A", "#3E7FB0", "#1E3F5A"],
            ["#315F89", "#417FAA", "#203E59"],
            ["#2B628D", "#427EB2", "#1D405D"],
        ]
        let names = palettes.map { PaletteNamer.descriptiveName(forHexes: $0, existingNames: []) }
        XCTAssertGreaterThan(Set(names).count, 1, "similar palettes should not all get \(names.first ?? "the same title")")
    }

    /// An AI name that duplicates an existing palette is replaced.
    func testDuplicateAINameIsReplaced() {
        let name = PaletteNamer.resolvedName(
            aiName: "Harbor Dusk",
            hexes: ["#2E5F8A", "#3E7FB0"],
            existingNames: ["harbor dusk"]
        )
        XCTAssertNotEqual(name.lowercased(), "harbor dusk")
        XCTAssertFalse(name.isEmpty)
    }

    /// A nil AI name (no Apple Intelligence / mock path) still gets a good name.
    func testNilAINameFallsBackToDescriptive() {
        let name = PaletteNamer.resolvedName(
            aiName: nil,
            hexes: ["#4E7A4F", "#6FA36F", "#2F4F2F"],
            existingNames: []
        )
        XCTAssertFalse(name.isEmpty)
        XCTAssertFalse(name.contains("Generated"))
    }

    // MARK: - Titles follow the loudest color

    /// The family word comes from the first chromatic swatch (a near-grey
    /// first swatch defers to a louder one), so a later loud accent does not
    /// name the title.
    func testTitleFamilyComesFromTheFirstChromaticColor() {
        let name = PaletteNamer.descriptiveName(
            forHexes: ["#2E5F8A", "#3E7FB0", "#1E3F5A", "#FF5A00"],
            existingNames: []
        )
        let warmFamilies = ["Garnet", "Coral", "Terracotta", "Ember", "Copper", "Apricot"]
        XCTAssertFalse(warmFamilies.contains { name.contains($0) }, "a blue palette with one orange accent: \(name)")
    }

    func testTitlesDropFillerWords() {
        let palettes = [
            ["#A9603F", "#C08552"], ["#2E5F8A", "#3E7FB0"], ["#4E7A4F", "#6FA36F"],
            ["#E8E2D8", "#D8D2C8"], ["#6B4E8A", "#8E6FB0"],
        ]
        var names: [String] = []
        for hexes in palettes {
            for _ in 0..<6 {
                names.append(PaletteNamer.descriptiveName(forHexes: hexes, existingNames: names))
            }
        }
        for name in names {
            for filler in ["Textured", "Woven", "Measured"] {
                XCTAssertFalse(name.contains(filler), name)
            }
        }
    }

    func testAITitleNamingAColorNotInThePaletteIsReplaced() {
        let name = PaletteNamer.resolvedName(
            aiName: "Crimson Tide",
            hexes: ["#2E5F8A", "#3E7FB0", "#1E3F5A"],
            existingNames: []
        )
        XCTAssertNotEqual(name, "Crimson Tide")
        XCTAssertFalse(name.isEmpty)
    }

    /// A near-grey first swatch next to a much louder one defers to the louder.
    func testNearGreyFirstSwatchDefersToTheChromaticOne() {
        let dullFirst = PaletteNamer.descriptiveName(forHexes: ["#8E7F7A", "#1F5FFF"], existingNames: [])
        XCTAssertTrue(dullFirst.contains("Cornflower"), dullFirst)
    }


    // MARK: - Vibe titles (plan 021 B3)

    private let blues = ["#1A89C5", "#00314D", "#A3D9FF", "#BD6783", "#8CA600", "#EEF6FD"]

    func testVibeKeywordsDropFillerAndToneWords() {
        XCTAssertEqual(PaletteNamer.vibeKeywords("ocean sunset"), ["ocean", "sunset"])
        XCTAssertEqual(PaletteNamer.vibeKeywords("a calm, warm autumn forest"), ["autumn", "forest"])
        XCTAssertEqual(PaletteNamer.vibeKeywords("ocean sunset. darker. more vivid"), ["ocean", "sunset"])
        XCTAssertEqual(PaletteNamer.vibeKeywords("   "), [])
        XCTAssertEqual(PaletteNamer.vibeKeywords(nil), [])
    }

    func testChangeAndPurposeWordsAreNotKeywords() {
        XCTAssertEqual(PaletteNamer.vibeKeywords("ocean sunset. add teal"), ["ocean", "sunset", "teal"])
        XCTAssertEqual(PaletteNamer.vibeKeywords("ocean website dashboard no"), ["ocean"])
        XCTAssertEqual(PaletteNamer.vibeKeywords("brand logo for a bakery"), ["bakery"])
    }

    func testAVibeTitleNeverNamesAColorThePaletteLacks() {
        // The user's oranges: "Blue Sunset" would mislead.
        let oranges = ["#D96532", "#F3A06B", "#8C3A18"]
        let name = PaletteNamer.resolvedName(aiName: nil, hexes: oranges, existingNames: [], vibe: "blue sunset")
        XCTAssertFalse(name.contains("Blue"), name)
    }

    func testAModelTitleThatRelatesToTheVibeIsKept() {
        // Shares a word.
        XCTAssertEqual(
            PaletteNamer.resolvedName(aiName: "Sunset Tide", hexes: blues, existingNames: [], vibe: "ocean sunset"),
            "Sunset Tide")
        // No word in common, but "harbor" reads blue like "ocean".
        XCTAssertEqual(
            PaletteNamer.resolvedName(aiName: "Harbor Light", hexes: blues, existingNames: [], vibe: "ocean sunset"),
            "Harbor Light")
    }

    func testAModelTitleThatIgnoresTheVibeIsReplacedByTheVibe() {
        let name = PaletteNamer.resolvedName(aiName: "Quiet Meadow", hexes: blues, existingNames: [], vibe: "ocean sunset")
        XCTAssertEqual(name, "Ocean Sunset")
    }

    func testTheVibeNamesThePaletteWhenThereIsNoModelTitle() {
        XCTAssertEqual(PaletteNamer.resolvedName(aiName: nil, hexes: blues, existingNames: [], vibe: "ocean sunset"), "Ocean Sunset")
        // A single word gets a character or closing word from the colors.
        let forest = PaletteNamer.resolvedName(aiName: nil, hexes: ["#2F6B3F", "#A7C4A0", "#1B2E22", "#D8E6D0"], existingNames: [], vibe: "forest")
        XCTAssertTrue(forest.contains("Forest"), forest)
        XCTAssertGreaterThan(forest.split(separator: " ").count, 1, forest)
    }

    func testVibeTitlesStayUnique() {
        let name = PaletteNamer.resolvedName(aiName: nil, hexes: blues, existingNames: ["Ocean Sunset", "ocean sunset"], vibe: "ocean sunset")
        XCTAssertNotEqual(name.lowercased(), "ocean sunset")
        XCTAssertTrue(name.contains("Ocean Sunset"), name)
    }

    func testNoVibeKeepsTheColorTitle() {
        let without = PaletteNamer.resolvedName(aiName: nil, hexes: blues, existingNames: [])
        XCTAssertEqual(PaletteNamer.resolvedName(aiName: nil, hexes: blues, existingNames: [], vibe: ""), without)
        XCTAssertEqual(PaletteNamer.resolvedName(aiName: "Quiet Meadow", hexes: blues, existingNames: [], vibe: nil), "Quiet Meadow")
    }
}
