//
//  AppDataPersistenceTests.swift
//  PalettesTests
//

import XCTest
import UIKit
import SwiftData
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

    /// An edit made just before a CloudKit-style reload must survive: the
    /// dirty-flag flush persists it before the reload replaces the arrays,
    /// so a later reload from the store still contains it.
    func testEditSurvivesReloadWindow() async throws {
        let appData = AppData(inMemory: true)
        let initialCount = appData.colors.count

        appData.colors.append(
            ColorViewModel(name: "Survivor", color: .red, HEX: "#FF0001", usedInPalette: false)
        )
        // Reload immediately, while the 300 ms debounce is still pending.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        // Fresh reload straight from the store.
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertEqual(appData.colors.count, initialCount + 1)
        XCTAssertTrue(appData.colors.contains { $0.name == "Survivor" })
    }

    /// A record inserted out-of-band (simulating a CloudKit import that
    /// landed after our snapshot) must not be deleted as an "orphan" by a
    /// subsequent local persist.
    func testFreshRemoteRecordNotDeletedByLocalPersist() async throws {
        let appData = AppData(inMemory: true)
        let context = try XCTUnwrap(appData.testContext)

        let remoteID = UUID()
        context.insert(StoredColor(
            id: remoteID,
            name: "Remote Arrival",
            hex: "#00FF00",
            usedInPalette: false,
            isFavorite: false,
            sortIndex: 999
        ))
        try context.save()

        // Local edit triggers a persist that diffs against a snapshot which
        // predates the remote record.
        appData.colors.append(
            ColorViewModel(name: "Local Edit", color: .blue, HEX: "#0000FF", usedInPalette: false)
        )
        try await Task.sleep(for: .seconds(1.5))

        let stored = try context.fetch(FetchDescriptor<StoredColor>())
        XCTAssertTrue(stored.contains { $0.id == remoteID },
                      "Freshly-synced remote record was deleted by a local persist")
    }

    /// A deliberate user deletion must stick: after removing a persisted
    /// color, a reload from the store must not resurrect it.
    func testExplicitDeleteSticks() async throws {
        let appData = AppData(inMemory: true)

        let doomed = ColorViewModel(name: "Doomed", color: .green, HEX: "#00FF01", usedInPalette: false)
        appData.colors.append(doomed)
        try await Task.sleep(for: .seconds(1.5))

        appData.colors.removeAll { $0.id == doomed.id }
        try await Task.sleep(for: .seconds(1.5))

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1))

        XCTAssertFalse(appData.colors.contains { $0.id == doomed.id },
                       "Deleted color reappeared after reload")
    }

    /// Round trip: a palette whose second color has a role must survive a
    /// save + reload-from-store cycle (same container, fresh read).
    func testColorRoleRoundTripsThroughPersistence() async throws {
        let appData = AppData(inMemory: true)
        let initialCount = appData.palettes.count

        let paletteColors = [
            PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: nil),
            PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: "Accent"),
        ]
        let palette = PaletteViewModel(name: "Role Round Trip", paletteColors: paletteColors)
        appData.palettes.append(palette)
        try await Task.sleep(for: .seconds(1.5))

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertEqual(appData.palettes.count, initialCount + 1)
        let reloaded = try XCTUnwrap(appData.palettes.first { $0.id == palette.id })
        XCTAssertEqual(reloaded.paletteColors[1].role, "Accent")
        XCTAssertNil(reloaded.paletteColors[0].role)
    }

    /// Legacy records (inserted before `colorRoles` existed) have an empty
    /// `colorRoles` array; hydration must map that to all-nil roles rather
    /// than crashing or misaligning indices.
    func testLegacyStoredPaletteWithoutColorRolesHydratesToNilRoles() async throws {
        let appData = AppData(inMemory: true)
        let context = try XCTUnwrap(appData.testContext)

        let legacyID = UUID()
        context.insert(StoredPalette(
            id: legacyID,
            name: "Legacy Palette",
            hexCodes: ["#111111", "#222222"],
            colorNames: ["One", "Two"],
            sortIndex: 999
        ))
        try context.save()

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        let reloaded = try XCTUnwrap(appData.palettes.first { $0.id == legacyID })
        XCTAssertEqual(reloaded.paletteColors.count, 2)
        XCTAssertNil(reloaded.paletteColors[0].role)
        XCTAssertNil(reloaded.paletteColors[1].role)
    }

    // MARK: - Custom tag library

    /// Adding a custom tag exposes it in `customTags` and the record must
    /// survive a save + reload-from-store cycle.
    func testAddCustomTagPersistsAndSurvivesReload() async throws {
        let appData = AppData(inMemory: true)

        XCTAssertTrue(appData.addCustomTag("Brand"))
        XCTAssertTrue(appData.customTags.contains("Brand"))

        try await Task.sleep(for: .seconds(1.5))
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        XCTAssertTrue(appData.customTags.contains("Brand"),
                       "Custom tag did not survive a reload from the store")
    }

    /// A new custom tag must not case-insensitively collide with one of the
    /// built-in `ColorRole.defaults`.
    func testAddCustomTagRejectsBuiltInCollisionCaseInsensitive() {
        let appData = AppData(inMemory: true)

        XCTAssertFalse(appData.addCustomTag("primary"))
        XCTAssertFalse(appData.customTags.contains { $0.caseInsensitiveCompare("primary") == .orderedSame })
    }

    /// A new custom tag must not case-insensitively collide with an existing
    /// custom tag either.
    func testAddCustomTagRejectsCaseInsensitiveDuplicateOfExistingCustomTag() {
        let appData = AppData(inMemory: true)

        XCTAssertTrue(appData.addCustomTag("Brand"))
        XCTAssertFalse(appData.addCustomTag("brand"))
        XCTAssertEqual(appData.customTags.filter { $0.caseInsensitiveCompare("brand") == .orderedSame }.count, 1)
    }

    /// Renaming a custom tag must rewrite the `role` on every palette color
    /// using it, and the rewrite must persist across a reload.
    func testRenameCustomTagRewritesRoleOnPaletteColorAndPersists() async throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.addCustomTag("Brand"))

        let paletteColors = [
            PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: "Brand"),
            PaletteColor(color: .blue, hex: "#0000FF", name: "Blue", role: nil),
        ]
        let palette = PaletteViewModel(name: "Tag Rename Test", paletteColors: paletteColors)
        appData.palettes.append(palette)
        try await Task.sleep(for: .seconds(1.5))

        appData.renameCustomTag("Brand", to: "Marketing")

        XCTAssertTrue(appData.customTags.contains("Marketing"))
        XCTAssertFalse(appData.customTags.contains("Brand"))
        let updated = try XCTUnwrap(appData.palettes.first { $0.id == palette.id })
        XCTAssertEqual(updated.paletteColors[0].role, "Marketing")
        try await Task.sleep(for: .seconds(1.5))

        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        try await Task.sleep(for: .seconds(1.5))

        let reloaded = try XCTUnwrap(appData.palettes.first { $0.id == palette.id })
        XCTAssertEqual(reloaded.paletteColors[0].role, "Marketing")
        XCTAssertTrue(appData.customTags.contains("Marketing"))
    }

    /// Renaming to a name that collides (case-insensitively) with an
    /// existing custom tag or a default role must be rejected (no-op).
    func testRenameCustomTagRejectsCollisionWithExistingOrDefault() {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.addCustomTag("Brand"))
        XCTAssertTrue(appData.addCustomTag("Marketing"))

        appData.renameCustomTag("Brand", to: "Marketing")
        XCTAssertTrue(appData.customTags.contains("Brand"),
                       "Rename colliding with an existing custom tag should be rejected")
        XCTAssertTrue(appData.customTags.contains("Marketing"))

        appData.renameCustomTag("Brand", to: "primary")
        XCTAssertTrue(appData.customTags.contains("Brand"),
                       "Rename colliding with a default role name should be rejected")
    }

    /// Deleting a custom tag must clear the role (to nil) on every palette
    /// color that used it.
    func testDeleteCustomTagClearsRoleToNil() async throws {
        let appData = AppData(inMemory: true)
        XCTAssertTrue(appData.addCustomTag("Brand"))

        let paletteColors = [
            PaletteColor(color: .red, hex: "#FF0000", name: "Red", role: "Brand"),
        ]
        let palette = PaletteViewModel(name: "Tag Delete Test", paletteColors: paletteColors)
        appData.palettes.append(palette)
        try await Task.sleep(for: .seconds(1.5))

        appData.deleteCustomTag("Brand")

        XCTAssertFalse(appData.customTags.contains("Brand"))
        let updated = try XCTUnwrap(appData.palettes.first { $0.id == palette.id })
        XCTAssertNil(updated.paletteColors[0].role)
    }
}
