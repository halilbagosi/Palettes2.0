//
//  ICloudSyncTests.swift
//  PalettesTests
//

import XCTest
import SwiftData
import CloudKit
@testable import Palettes

@MainActor
final class ICloudSyncTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "ICloudSyncTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// One in-memory store per mode, kept for the test's lifetime, so
    /// switching back to a mode reopens the same data like the real files.
    @MainActor private final class Stores {
        nonisolated deinit {}
        var byMode: [LibraryStoreMode: ModelContainer] = [:]
        func container(_ mode: LibraryStoreMode) -> ModelContainer? {
            if let existing = byMode[mode] { return existing }
            let made = ICloudSync.makeInMemoryContainer(name: "\(mode)")
            byMode[mode] = made
            return made
        }
        func paletteNames(_ mode: LibraryStoreMode) throws -> Set<String> {
            let context = try XCTUnwrap(byMode[mode]).mainContext
            return Set(try context.fetch(FetchDescriptor<StoredPalette>()).map(\.name))
        }
    }

    private func seed(_ stores: Stores, _ mode: LibraryStoreMode, palettes names: [String]) throws {
        let context = try XCTUnwrap(stores.container(mode)).mainContext
        for (i, name) in names.enumerated() {
            context.insert(StoredPalette(id: UUID(), name: name, hexCodes: ["#112233"],
                                         colorNames: ["Ink"], sortIndex: i))
        }
        try context.save()
    }

    // MARK: Preference

    func testFreshInstallStartsWithSyncOff() {
        XCTAssertFalse(ICloudSync.isEnabled(defaults, legacyStoreExists: { false }))
    }

    func testInstallFromBeforeTheToggleKeepsSyncing() {
        XCTAssertTrue(ICloudSync.isEnabled(defaults, legacyStoreExists: { true }))
        XCTAssertFalse(defaults.bool(forKey: ICloudSync.promptAnsweredKey), "still asked once")
    }

    func testRecordedChoiceWinsOverLegacyStore() {
        defaults.set(false, forKey: ICloudSync.enabledKey)
        XCTAssertFalse(ICloudSync.isEnabled(defaults, legacyStoreExists: { true }))
    }

    func testPromptOnlyAfterOnboardingAndOnce() {
        XCTAssertFalse(ICloudSync.shouldPrompt(onboardingComplete: false, alreadyAnswered: false))
        XCTAssertTrue(ICloudSync.shouldPrompt(onboardingComplete: true, alreadyAnswered: false))
        XCTAssertFalse(ICloudSync.shouldPrompt(onboardingComplete: true, alreadyAnswered: true))
    }

    // MARK: Merge helpers

    func testMergeKeepsBaseCopyAndAppendsNewOnes() {
        let shared = ColorViewModel(name: "Mine", color: .red, HEX: "#FF0000", usedInPalette: false)
        var theirs = shared
        theirs.name = "Theirs"
        let extra = ColorViewModel(name: "Extra", color: .blue, HEX: "#0000FF", usedInPalette: false)
        let merged = ICloudSync.merge([shared], [theirs, extra])
        XCTAssertEqual(merged.map(\.name), ["Mine", "Extra"])
    }

    func testMergeTagsIsCaseInsensitive() {
        XCTAssertEqual(ICloudSync.mergeTags(["Brand"], ["brand", "Web"]), ["Brand", "Web"])
    }

    // MARK: Switching stores

    func testTurningOnWithMergeCombinesBothLibraries() throws {
        let stores = Stores()
        try seed(stores, .local, palettes: ["On this device"])
        try seed(stores, .cloud, palettes: ["From iCloud"])
        let appData = AppData(inMemory: true, syncEnabled: false, storeFactory: stores.container)
        XCTAssertEqual(appData.storeMode, .local)

        XCTAssertTrue(appData.setICloudSync(enabled: true, choice: .merge, defaults: defaults))

        XCTAssertEqual(appData.storeMode, .cloud)
        XCTAssertEqual(Set(appData.palettes.map(\.name)), ["On this device", "From iCloud"])
        XCTAssertEqual(try stores.paletteNames(.cloud), ["On this device", "From iCloud"])
        XCTAssertTrue(defaults.bool(forKey: ICloudSync.enabledKey))
    }

    func testTurningOnWithReplaceUsesOnlyICloud() throws {
        let stores = Stores()
        try seed(stores, .local, palettes: ["On this device"])
        try seed(stores, .cloud, palettes: ["From iCloud"])
        let appData = AppData(inMemory: true, syncEnabled: false, storeFactory: stores.container)

        XCTAssertTrue(appData.setICloudSync(enabled: true, choice: .replaceWithICloud, defaults: defaults))

        XCTAssertEqual(appData.palettes.map(\.name), ["From iCloud"])
        XCTAssertEqual(try stores.paletteNames(.cloud), ["From iCloud"], "nothing local is uploaded")
    }

    func testTurningOffCopiesLibraryToThisDeviceAndLeavesICloudAlone() throws {
        let stores = Stores()
        try seed(stores, .local, palettes: ["Stale local copy"])
        try seed(stores, .cloud, palettes: ["Synced"])
        let appData = AppData(inMemory: true, syncEnabled: true, storeFactory: stores.container)
        XCTAssertEqual(appData.storeMode, .cloud)

        XCTAssertTrue(appData.setICloudSync(enabled: false, defaults: defaults))

        XCTAssertEqual(appData.storeMode, .local)
        XCTAssertEqual(appData.palettes.map(\.name), ["Synced"])
        XCTAssertEqual(try stores.paletteNames(.local), ["Synced"], "local store replaced, not merged")
        XCTAssertEqual(try stores.paletteNames(.cloud), ["Synced"])
        XCTAssertFalse(defaults.bool(forKey: ICloudSync.enabledKey))
    }

    func testFallsBackToLocalWhenICloudStoreWontOpen() {
        let stores = Stores()
        let appData = AppData(inMemory: true, syncEnabled: true, storeFactory: { mode in
            mode == .cloud ? nil : stores.container(mode)
        })
        XCTAssertEqual(appData.storeMode, .local)
        XCTAssertTrue(appData.iCloudStoreUnavailable)
        XCTAssertFalse(appData.setICloudSync(enabled: true, defaults: defaults))
        XCTAssertEqual(appData.storeMode, .local)
    }

    // MARK: Sync errors

    private func ckError(_ code: CKError.Code, server: String? = nil, partial: [AnyHashable: Error]? = nil) -> NSError {
        var info: [String: Any] = [:]
        if let server { info["ServerErrorDescription"] = server }
        if let partial { info[CKPartialErrorsByItemIDKey] = partial }
        return NSError(domain: CKErrorDomain, code: code.rawValue, userInfo: info)
    }

    func testPartialFailureIsDescribedByItsCommonestRecordError() {
        let error = ckError(.partialFailure, partial: [
            "a": ckError(.batchRequestFailed),
            "b": ckError(.quotaExceeded),
            "c": ckError(.batchRequestFailed),
            "d": ckError(.quotaExceeded),
            "e": ckError(.serverRecordChanged),
        ])
        XCTAssertEqual(ICloudSync.underlyingCause(of: error).code, CKError.Code.quotaExceeded.rawValue)
        XCTAssertEqual(ICloudSync.describe(error), "Your iCloud storage is full. (CloudKit error 25)")
    }

    func testMissingProductionSchemaIsNamed() {
        let error = ckError(.partialFailure, partial: [
            "a": ckError(.invalidArguments, server: "Cannot create new type CD_StoredTag in production schema"),
        ])
        XCTAssertEqual(ICloudSync.describe(error),
                       "iCloud isn't set up for this version of Palettes yet. (CloudKit error 12)")
    }

    func testPartialFailureWithoutRecordErrorsFallsBackToItself() {
        let error = ckError(.partialFailure)
        XCTAssertEqual(ICloudSync.underlyingCause(of: error), error)
    }

    func testNonCloudKitErrorKeepsItsOwnDescription() {
        let error = NSError(domain: "Other", code: 1, userInfo: [NSLocalizedDescriptionKey: "Disk is full"])
        XCTAssertEqual(ICloudSync.describe(error), "Disk is full")
    }
}
