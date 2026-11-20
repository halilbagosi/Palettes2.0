import XCTest
import SwiftData
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

    func testDisplayIsIdempotentAtTheCap() {
        let long = String(repeating: "ab ", count: 60)
        let once = NameLimit.display(long)
        XCTAssertLessThanOrEqual(once.count, NameLimit.maxLength)
        XCTAssertEqual(NameLimit.display(once), once)
    }

    func testLookupsCompareTitledInput() {
        let appData = AppData(inMemory: true)
        appData.addColor(name: "Dusty Rose", hex: "#C08081")
        XCTAssertNotNil(appData.existingColor(named: "dusty  rose"))
        appData.addPalette(name: "Warm Autumn", paletteColors: [])
        XCTAssertNotNil(appData.existingPalette(named: "warm  autumn"))
    }

    func testMigrationWritesTitledNamesOnceAndSetsFlag() throws {
        let suite = "NameCaseMigrationTests"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let appData = AppData(inMemory: true)
        let context = try XCTUnwrap(appData.testContext)
        context.insert(StoredColor(id: UUID(), name: "dusty rose", hex: "#C08081", usedInPalette: false, sortIndex: 0))
        try context.save()
        appData.reloadFromStore()

        appData.migrateTitleCaseNamesIfNeeded(defaults: defaults)

        let stored = try context.fetch(FetchDescriptor<StoredColor>())
        XCTAssertEqual(stored.map(\.name), ["Dusty Rose"])
        XCTAssertTrue(defaults.bool(forKey: AppData.titleCaseMigrationKey))
    }
}
