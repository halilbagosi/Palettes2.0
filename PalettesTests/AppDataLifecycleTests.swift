//
//  AppDataLifecycleTests.swift
//  PalettesTests
//

import XCTest
import SwiftData
@testable import Palettes

@MainActor
final class AppDataLifecycleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
        UserDefaults.standard.removeObject(forKey: AppData.recentSearchesKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
        UserDefaults.standard.removeObject(forKey: AppData.recentSearchesKey)
        super.tearDown()
    }

    /// No sample data: a fresh install starts empty (onboarding creates the
    /// first palette later), and nothing is written to the store.
    func testFirstLaunchStartsEmpty() throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.colors.isEmpty)
        XCTAssertTrue(appData.palettes.isEmpty)
        XCTAssertTrue(appData.customTags.isEmpty)
        let context = try XCTUnwrap(appData.testContext)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredColor>()), 0)
    }

    func testFlushPersistsEditBeforeDebounce() throws {
        let appData = AppData(inMemory: true)
        let added = ColorViewModel(name: "Flush Me", color: .red, HEX: "#FF0002", usedInPalette: false)
        appData.colors.append(added)
        appData.flushPendingChanges()
        let stored = try XCTUnwrap(appData.testContext).fetch(FetchDescriptor<StoredColor>())
        XCTAssertTrue(stored.contains { $0.id == added.id })
    }

    func testDeleteAllRemovesEverythingIncludingUnknownRemoteRecords() throws {
        let appData = AppData(inMemory: true)
        _ = appData.addCustomTag("Brand")
        appData.flushPendingChanges()
        // Simulate a record imported from another device that AppData hasn't loaded yet.
        let context = try XCTUnwrap(appData.testContext)
        context.insert(StoredPalette(id: UUID(), name: "Remote", hexCodes: ["#123456"], colorNames: ["X"], sortIndex: 99))
        try context.save()
        UserDefaults.standard.set("[\"blue\"]", forKey: AppData.recentSearchesKey)

        XCTAssertTrue(appData.deleteAllLibraryData())

        XCTAssertTrue(appData.colors.isEmpty)
        XCTAssertTrue(appData.palettes.isEmpty)
        XCTAssertTrue(appData.customTags.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredColor>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredTag>()), 0)
        XCTAssertNil(UserDefaults.standard.string(forKey: AppData.recentSearchesKey))
    }

    func testDeleteAllStaysEmptyAfterDebounceWindow() async throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.deleteAllLibraryData())
        try await Task.sleep(for: .seconds(1))
        let context = try XCTUnwrap(appData.testContext)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<StoredPalette>()), 0)
        XCTAssertTrue(appData.palettes.isEmpty)
    }

    func testLibraryExportRoundTripsAllUserData() throws {
        let appData = AppData(inMemory: true)
        appData.addColor(name: "Ocean", hex: "#0077BE")
        appData.addPalette(name: "Coast", paletteColors: [
            PaletteColor(color: .blue, hex: "#0077BE", name: "Ocean"),
            PaletteColor(color: .yellow, hex: "#C2B280", name: "Sand"),
        ])
        _ = appData.addCustomTag("Brand")
        appData.palettes[0].paletteColors[0].role = "Brand"
        appData.palettes[0].isFavorite = true
        let date = Date(timeIntervalSince1970: 1_800_000_000)

        let export = appData.libraryExport(now: date)
        let decoded = try LibraryExport.decode(export.jsonData())

        XCTAssertEqual(decoded, export)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.colors.count, appData.colors.count)
        XCTAssertEqual(decoded.palettes.count, appData.palettes.count)
        XCTAssertEqual(decoded.customTags, ["Brand"])
        XCTAssertEqual(decoded.palettes[0].colors[0].role, "Brand")
        XCTAssertTrue(decoded.palettes[0].isFavorite)
        XCTAssertEqual(decoded.palettes[0].id, appData.palettes[0].id)
    }
}
