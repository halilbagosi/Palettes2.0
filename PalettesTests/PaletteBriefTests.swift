//
//  PaletteBriefTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteBriefTests: XCTestCase {

    func testResolvedSize() {
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: nil, locked: 0, suggested: nil), 6)
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: nil, locked: 3, suggested: 5), 5)
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: nil, locked: 8, suggested: nil), 8)
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: nil, locked: 0, suggested: 20), 12)
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: 4, locked: 6, suggested: nil), 6)
        XCTAssertEqual(PaletteBrief.resolvedSize(requested: 10, locked: 0, suggested: 5), 10)
    }

    func testHeuristicSuggestsNoSize() {
        XCTAssertNil(PaletteBrief.heuristic(from: "calm forest").suggestedSize)
    }

    func testColorWordSetsTheHue() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "moody navy library").hue, 262)
        XCTAssertEqual(PaletteBrief.heuristic(from: "Cerulean").hue, 240)
    }

    func testColorWordBeatsAPlaceWord() {
        // "ocean" alone reads as blue; the color word wins.
        XCTAssertEqual(PaletteBrief.heuristic(from: "terracotta by the ocean").hue, 45)
    }

    func testPlaceWordSetsTheHueWhenNoColorIsNamed() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "sunset over the ocean").hue, 45)
        XCTAssertNil(PaletteBrief.heuristic(from: "neon arcade").hue)
    }

    func testToneWords() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "moody navy library").tone, PaletteTone(lightness: .dark))
        XCTAssertEqual(PaletteBrief.heuristic(from: "pastel spring garden").tone, PaletteTone(lightness: .light, chroma: .muted))
        XCTAssertEqual(PaletteBrief.heuristic(from: "neon arcade").tone, PaletteTone(chroma: .vivid))
        XCTAssertEqual(PaletteBrief.heuristic(from: "calm").tone, PaletteTone(chroma: .muted))
    }

    func testHarmonyWords() {
        XCTAssertEqual(PaletteBrief.heuristic(from: "monochrome lavender").scheme, .monochromatic)
        XCTAssertEqual(PaletteBrief.heuristic(from: "complementary sunset").scheme, .complementary)
        XCTAssertNil(PaletteBrief.heuristic(from: "warm autumn forest").scheme)
    }

    func testHueForColorWord() {
        XCTAssertEqual(PaletteBrief.hue(forColorWord: "navy"), 262)
        // "Tomato" is only in the color dictionary.
        let tomato = PaletteBrief.hue(forColorWord: "Tomato")
        XCTAssertNotNil(tomato)
        XCTAssertEqual(ColorVocabulary.family(forHue: tomato ?? 0), .red)
        XCTAssertNil(PaletteBrief.hue(forColorWord: "Gray"), "a grey has no hue")
        XCTAssertNil(PaletteBrief.hue(forColorWord: "unicorn"))
    }
}
