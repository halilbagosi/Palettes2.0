//
//  SearchMatchingTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

final class SearchMatchingTests: XCTestCase {

    // MARK: - paletteMatchesQuery: existing name/colorName/hex behavior preserved

    func testMatchesByName() {
        let palette = PaletteViewModel(name: "Sunset Beach", colors: [.red], hexCodes: ["#FF0000"], colorNames: ["Red"])
        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "sunset", hexQuery: "sunset"))
        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "SUNSET", hexQuery: "SUNSET"))
    }

    func testMatchesByColorName() {
        let palette = PaletteViewModel(name: "Ocean", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Cerulean"])
        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "cerulean", hexQuery: "cerulean"))
    }

    func testMatchesByHex() {
        let palette = PaletteViewModel(name: "Ocean", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Cerulean"])
        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "0000FF", hexQuery: "0000FF"))
        // "#" prefix is stripped by the caller before it reaches hexQuery.
        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "#0000FF", hexQuery: "0000FF"))
    }

    func testDoesNotMatchUnrelatedQuery() {
        let palette = PaletteViewModel(name: "Ocean", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Cerulean"])
        XCTAssertFalse(SearchMatching.paletteMatchesQuery(palette, query: "mountain", hexQuery: "mountain"))
    }

    func testEmptyHexQuerySkipsHexMatching() {
        // Mirrors current predicate: `(!hexQuery.isEmpty && ...)` short-circuits when hexQuery is empty.
        let palette = PaletteViewModel(name: "X", colors: [.blue], hexCodes: [""], colorNames: ["Y"])
        XCTAssertFalse(SearchMatching.paletteMatchesQuery(palette, query: "", hexQuery: ""))
    }

    // MARK: - paletteMatchesQuery: new role-name matching

    func testMatchesByRoleNameWhenNameAndHexDoNotContainQuery() {
        let palette = PaletteViewModel(
            name: "Ocean Breeze",
            paletteColors: [
                PaletteColor(color: .blue, hex: "#1E90FF", name: "Dodger Blue", role: "Primary")
            ]
        )
        // Sanity: the query text isn't present anywhere except the role tag.
        XCTAssertFalse(palette.name.localizedCaseInsensitiveContains("primary"))
        XCTAssertFalse(palette.hexCodes.contains(where: { $0.localizedCaseInsensitiveContains("primary") }))
        XCTAssertFalse(palette.colorNames.contains(where: { $0.localizedCaseInsensitiveContains("primary") }))

        XCTAssertTrue(SearchMatching.paletteMatchesQuery(palette, query: "primary", hexQuery: "primary"))
    }

    func testDoesNotMatchRoleWhenQueryAbsent() {
        let palette = PaletteViewModel(
            name: "Ocean Breeze",
            paletteColors: [
                PaletteColor(color: .blue, hex: "#1E90FF", name: "Dodger Blue", role: "Secondary")
            ]
        )
        XCTAssertFalse(SearchMatching.paletteMatchesQuery(palette, query: "primary", hexQuery: "primary"))
    }

    // MARK: - paletteMatchesTags

    func testMatchesTagsAnyOf() {
        let palette = PaletteViewModel(
            name: "P",
            paletteColors: [
                PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Primary"),
                PaletteColor(color: .green, hex: "#00FF00", name: "Green", role: "Accent")
            ]
        )
        XCTAssertTrue(SearchMatching.paletteMatchesTags(palette, tags: ["Accent"]))
        XCTAssertTrue(SearchMatching.paletteMatchesTags(palette, tags: ["Warning", "Primary"]))
        XCTAssertFalse(SearchMatching.paletteMatchesTags(palette, tags: ["Warning", "Border"]))
    }

    func testMatchesTagsCaseInsensitive() {
        let palette = PaletteViewModel(
            name: "P",
            paletteColors: [PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Primary")]
        )
        XCTAssertTrue(SearchMatching.paletteMatchesTags(palette, tags: ["primary"]))
        XCTAssertTrue(SearchMatching.paletteMatchesTags(palette, tags: ["PRIMARY"]))
    }

    func testMatchesTagsEmptySetMatchesEverything() {
        let untagged = PaletteViewModel(name: "P", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Blue"])
        XCTAssertTrue(SearchMatching.paletteMatchesTags(untagged, tags: []))
    }

    func testUntaggedPaletteDoesNotMatchNonEmptyTags() {
        let untagged = PaletteViewModel(name: "P", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Blue"])
        XCTAssertFalse(SearchMatching.paletteMatchesTags(untagged, tags: ["Primary"]))
    }

    // MARK: - tagsInUse

    func testTagsInUseOrdersBuiltinsFirstThenCustomsAlphabetical() {
        let palettes = [
            PaletteViewModel(name: "P1", paletteColors: [
                PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Warning"),
                PaletteColor(color: .green, hex: "#00FF00", name: "Green", role: "Zephyr")
            ]),
            PaletteViewModel(name: "P2", paletteColors: [
                PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: "Primary"),
                PaletteColor(color: .yellow, hex: "#FFFF00", name: "Yellow", role: "Alpha")
            ])
        ]
        XCTAssertEqual(SearchMatching.tagsInUse(palettes: palettes), ["Primary", "Warning", "Alpha", "Zephyr"])
    }

    func testTagsInUseDedupesExactRepeats() {
        let palettes = [
            PaletteViewModel(name: "P1", paletteColors: [
                PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Primary")
            ]),
            PaletteViewModel(name: "P2", paletteColors: [
                PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: "Primary")
            ])
        ]
        XCTAssertEqual(SearchMatching.tagsInUse(palettes: palettes), ["Primary"])
    }

    func testTagsInUseDedupesCaseVariants() {
        let palettes = [
            PaletteViewModel(name: "P1", paletteColors: [
                PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Highlight")
            ]),
            PaletteViewModel(name: "P2", paletteColors: [
                PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: "highlight")
            ])
        ]
        XCTAssertEqual(SearchMatching.tagsInUse(palettes: palettes), ["Highlight"])
    }

    func testTagsInUseEmptyWhenNoTaggedColors() {
        let palettes = [
            PaletteViewModel(name: "P1", colors: [.blue], hexCodes: ["#0000FF"], colorNames: ["Blue"])
        ]
        XCTAssertEqual(SearchMatching.tagsInUse(palettes: palettes), [])
    }
}
