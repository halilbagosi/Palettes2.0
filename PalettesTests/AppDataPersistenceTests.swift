//
//  AppDataPersistenceTests.swift
//  PalettesTests
//

import XCTest
@testable import Palettes

@MainActor
final class AppDataPersistenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "didSeedSampleData")
        super.tearDown()
    }

    /// First-launch seeding: with no prior seed flag and an empty in-memory
    /// store, AppData should populate the sample library.
    func testFirstLaunchSeedsSampleColorsAndPalettes() {
        let appData = AppData(inMemory: true)

        XCTAssertEqual(appData.colors.count, 11)
        XCTAssertEqual(appData.palettes.count, 5)
    }

    /// Smoke test: mutating colors/palettes twice in succession (across the
    /// 300ms debounce window) must not crash.
    // TODO(plan-002): needs a testable reload seam
    func testRepeatedMutationsDoNotCrash() async throws {
        let appData = AppData(inMemory: true)

        appData.colors.append(
            ColorViewModel(name: "Test Color", color: .red, HEX: "#FF0000", usedInPalette: false)
        )
        try await Task.sleep(for: .seconds(1))

        appData.colors.removeLast()
        try await Task.sleep(for: .seconds(1))

        // Reaching this point without a crash/hang is the assertion.
        XCTAssertTrue(true)
    }
}
