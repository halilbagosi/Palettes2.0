//
//  PaletteRefinementTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class PaletteRefinementTests: XCTestCase {

    private let recipe = GenerationRecipe(
        brief: PaletteBrief(hue: nil, tone: .balanced, scheme: nil),
        size: 6,
        scheme: .auto,
        seed: 42,
        builtHue: 200
    )

    private func build(_ recipe: GenerationRecipe) -> BuiltPalette {
        PaletteBuilder.build(PaletteBuildRequest(
            anchors: [], size: recipe.size, scheme: recipe.scheme,
            tone: recipe.brief.tone, hue: recipe.brief.hue, seed: recipe.seed))
    }

    // MARK: - Reading a change

    func testRelativeWords() {
        XCTAssertEqual(PaletteChange.heuristic(from: "make it darker").lightness, -1)
        XCTAssertEqual(PaletteChange.heuristic(from: "a bit lighter please").lightness, 1)
        XCTAssertEqual(PaletteChange.heuristic(from: "more muted").chroma, -1)
        XCTAssertEqual(PaletteChange.heuristic(from: "bolder").chroma, 1)
        XCTAssertEqual(PaletteChange.heuristic(from: "warmer").temperature, 1)
        XCTAssertEqual(PaletteChange.heuristic(from: "cooler tones").temperature, -1)
    }

    func testColorWordSetsTheMainHue() {
        XCTAssertEqual(PaletteChange.heuristic(from: "make it teal").mainHue, 190)
        // The last color word wins.
        XCTAssertEqual(PaletteChange.heuristic(from: "less blue, more green").mainHue, 145)
    }

    func testColorCount() {
        XCTAssertEqual(PaletteChange.heuristic(from: "add more colors").sizeDelta, 1)
        XCTAssertEqual(PaletteChange.heuristic(from: "fewer colors").sizeDelta, -1)
        XCTAssertEqual(PaletteChange.heuristic(from: "only 4 colors").size, 4)
        XCTAssertEqual(PaletteChange.heuristic(from: "five colours").size, 5)
        // "more" alone is about something else.
        XCTAssertEqual(PaletteChange.heuristic(from: "more vivid").sizeDelta, 0)
    }

    func testUnrelatedWordsAreNoChange() {
        XCTAssertTrue(PaletteChange.heuristic(from: "more like a beach").isEmpty)
    }

    // MARK: - Applying a change

    func testStepsMoveOneNotchAndStopAtTheEnds() {
        let darker = recipe.applying(PaletteChange(lightness: -1), lockedCount: 0)
        XCTAssertEqual(darker.brief.tone.lightness, .dark)
        XCTAssertEqual(darker.applying(PaletteChange(lightness: -1), lockedCount: 0).brief.tone.lightness, .dark)
        XCTAssertEqual(recipe.applying(PaletteChange(chroma: 1), lockedCount: 0).brief.tone.chroma, .vivid)
    }

    func testChangeKeepsTheSeed() {
        let changed = recipe.applying(PaletteChange(lightness: 1), lockedCount: 0)
        XCTAssertEqual(changed.seed, recipe.seed)
        XCTAssertEqual(changed.scheme, recipe.scheme)
        XCTAssertEqual(changed.size, recipe.size)
    }

    func testWarmthShiftsTheBuiltHueTowardThePole() {
        let warmer = recipe.applying(PaletteChange(temperature: 1), lockedCount: 0)
        XCTAssertEqual(warmer.brief.hue ?? -1, 165, accuracy: 0.001)
        let cooler = recipe.applying(PaletteChange(temperature: -1), lockedCount: 0)
        XCTAssertEqual(cooler.brief.hue ?? -1, 235, accuracy: 0.001)
        // Wraps the short way round.
        XCTAssertEqual(GenerationRecipe.shift(hue: 350, warmer: true), 25, accuracy: 0.001)
    }

    func testSizeIsClampedToLockedColors() {
        XCTAssertEqual(recipe.applying(PaletteChange(sizeDelta: 1), lockedCount: 0).size, 7)
        XCTAssertEqual(recipe.applying(PaletteChange(size: 3), lockedCount: 5).size, 5)
        XCTAssertEqual(recipe.applying(PaletteChange(size: 40), lockedCount: 0).size, 12)
    }

    func testInterfaceModeKeepsItsScheme() {
        var ui = recipe
        ui.scheme = .uiDark
        XCTAssertEqual(ui.applying(PaletteChange(scheme: .triadic), lockedCount: 0).scheme, .uiDark)
    }

    func testDarkerRebuildsTheSamePaletteDarker() {
        let before = build(recipe)
        let after = build(recipe.applying(PaletteChange(lightness: -1), lockedCount: 0))
        XCTAssertEqual(before.hexes.count, after.hexes.count)
        XCTAssertNotEqual(before.hexes, after.hexes)
        let lightness = { (hexes: [String]) in
            hexes.compactMap { OKLCH(hex: $0)?.L }.reduce(0, +) / Double(hexes.count)
        }
        XCTAssertLessThan(lightness(after.hexes), lightness(before.hexes))
        // Same seed, same main hue.
        XCTAssertEqual(before.mainHue ?? -1, after.mainHue ?? -2, accuracy: 3)
    }
}
