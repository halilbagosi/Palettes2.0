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
}
