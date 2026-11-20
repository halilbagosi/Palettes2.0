import XCTest
@testable import Palettes

@MainActor
final class NameCaseTests: XCTestCase {
    func testBasicTitleCase() {
        XCTAssertEqual(NameCase.titled("dusty rose"), "Dusty Rose")
        XCTAssertEqual(NameCase.titled("  deep   teal "), "Deep Teal")
    }

    func testMinorWordsStayLowercaseExceptFirstAndLast() {
        XCTAssertEqual(NameCase.titled("the king of the hill"), "The King of the Hill")
        XCTAssertEqual(NameCase.titled("shades of"), "Shades Of")
        XCTAssertEqual(NameCase.titled("salt and pepper"), "Salt and Pepper")
    }

    func testHyphenatedPartsCapitalized() {
        XCTAssertEqual(NameCase.titled("blue-green"), "Blue-Green")
    }

    func testPreservesDeliberateCapitals() {
        XCTAssertEqual(NameCase.titled("iPhone Blue"), "iPhone Blue")
        XCTAssertEqual(NameCase.titled("UI red"), "UI Red")
    }

    func testEmpty() {
        XCTAssertEqual(NameCase.titled("   "), "")
    }

    func testColorNamerPreferredNamesAreTitled() {
        let names = ColorNamer.uniqueNames(forHexes: ["#FF0000", "#00FF00"], preferred: ["fire engine", nil])
        XCTAssertEqual(names[0], "Fire Engine")
    }

    func testViewModelsTitleNames() {
        var color = ColorViewModel(name: "ocean mist", color: .red, HEX: "#FF0000", usedInPalette: false)
        XCTAssertEqual(color.name, "Ocean Mist")
        color.name = "deep sea"
        XCTAssertEqual(color.name, "Deep Sea")
        let palette = PaletteViewModel(name: "warm autumn", paletteColors: [])
        XCTAssertEqual(palette.name, "Warm Autumn")
    }
}
