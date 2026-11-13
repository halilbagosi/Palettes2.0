//
//  ICloudSync.swift
//  Palettes
//
//  The iCloud sync preference and the two on-disk stores it switches between.
//  Synced (`default.store`) and local (`Local.store`) libraries live in separate files so turning sync off and
//  on again never replays local-only edits (or deletions) into iCloud by
//  accident. `AppData` owns the switch; this file is the pure parts.
//

import Foundation
import SwiftData
import CoreData
import CloudKit
import os

/// Which store `AppData` reads and writes.
enum LibraryStoreMode: Equatable {
    /// `Local.store`, never mirrored.
    case local
    /// `default.store`, mirrored to the user's private CloudKit database.
    case cloud
}

/// What happens to this device's library when sync is turned on.
enum ICloudSyncMergeChoice: Equatable {
    /// Keep this device's palettes and colors and add iCloud's to them.
    case merge
    /// Drop this device's library and use what's in iCloud.
    case replaceWithICloud
}

enum ICloudSync {
    static let enabledKey = "iCloudSyncEnabled"
    /// Set once the post-onboarding "Sync with iCloud?" question is answered.
    static let promptAnsweredKey = "iCloudSyncPromptAnswered"

    static let logger = Logger(subsystem: "com.halilbagosi.Palettes", category: "iCloudSync")

    /// The synced store. Deliberately the exact configuration the app used
    /// before sync could be turned off (default name and location,
    /// `.automatic` container): CloudKit mirroring treats any change here as
    /// a different store and resets it, which crashed launches mid-reset.
    static func cloudConfiguration() -> ModelConfiguration {
        ModelConfiguration(cloudKitDatabase: .automatic)
    }

    static func localConfiguration() -> ModelConfiguration {
        ModelConfiguration("Local", schema: schema, cloudKitDatabase: .none)
    }

    static var cloudStoreURL: URL { cloudConfiguration().url }

    /// One shared instance: a container doesn't keep a schema it was handed
    /// alive, and a freed one leaves the store with no usable connection.
    static let schema = Schema([StoredColor.self, StoredPalette.self, StoredTag.self])

    /// The stored preference. Installs from before the toggle existed always
    /// synced into `default.store`, so if that file is there and no choice has
    /// been recorded, they start with sync on (the post-onboarding prompt
    /// still asks once). Fresh installs start local until the user opts in.
    static func isEnabled(_ defaults: UserDefaults = .standard,
                          legacyStoreExists: () -> Bool = { FileManager.default.fileExists(atPath: cloudStoreURL.path) }) -> Bool {
        if defaults.object(forKey: enabledKey) == nil {
            defaults.set(legacyStoreExists(), forKey: enabledKey)
        }
        return defaults.bool(forKey: enabledKey)
    }

    /// Opens the on-disk store for `mode`, or nil if it can't be opened.
    static func makeContainer(_ mode: LibraryStoreMode) -> ModelContainer? {
        #if DEBUG
        if mode == .cloud, ProcessInfo.processInfo.arguments.contains(initializeSchemaArgument) {
            initializeCloudKitSchema()
        }
        #endif
        let config = mode == .cloud ? cloudConfiguration() : localConfiguration()
        do {
            return try ModelContainer(for: StoredColor.self, StoredPalette.self, StoredTag.self, configurations: config)
        } catch {
            logger.error("Couldn't open the \(mode == .cloud ? "iCloud" : "local", privacy: .public) store: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// A throwaway store for previews, tests and screenshots. Never mirrored:
    /// `ModelConfiguration` defaults to `.automatic`, and CloudKit setup racing
    /// the first fetch on an in-memory store crashed launches ("No eligible
    /// connection available"). `name` lets tests hold two at once.
    static func makeInMemoryContainer(name: String? = nil) -> ModelContainer? {
        let config = ModelConfiguration(name, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try? ModelContainer(for: StoredColor.self, StoredPalette.self, StoredTag.self, configurations: config)
    }

    /// Whether the post-onboarding question should be asked now.
    static func shouldPrompt(onboardingComplete: Bool, alreadyAnswered: Bool) -> Bool {
        onboardingComplete && !alreadyAnswered
    }

    /// Changing sync in Settings counts as answering the post-onboarding question.
    static func markPromptAnswered(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: promptAnsweredKey)
    }

    // MARK: Merge

    /// Everything in `incoming` that `base` doesn't already hold (by id) is
    /// appended after it; where both hold an id, `base`'s copy wins.
    static func merge<T: Identifiable>(_ base: [T], _ incoming: [T]) -> [T] where T.ID: Hashable {
        var seen = Set(base.map(\.id))
        return base + incoming.filter { seen.insert($0.id).inserted }
    }

    /// Tag names are unique case-insensitively.
    static func mergeTags(_ base: [String], _ incoming: [String]) -> [String] {
        var seen = Set(base.map { $0.lowercased() })
        return base + incoming.filter { seen.insert($0.lowercased()).inserted }
    }

    // MARK: Sync errors

    /// What Settings shows when a CloudKit export or import fails.
    ///
    /// CloudKit reports almost every failed export as a partial failure,
    /// whose own description ("Failed to modify some records") says nothing.
    /// The real reason is in the per-record errors underneath, so this digs
    /// out the most common one and words it for the user, keeping CloudKit's
    /// code so a report can be traced.
    static func describe(_ error: Error) -> String {
        let cause = underlyingCause(of: error as NSError)
        guard cause.domain == CKErrorDomain, let code = CKError.Code(rawValue: cause.code) else {
            return cause.localizedDescription
        }
        let server = (cause.userInfo["ServerErrorDescription"] as? String)
            ?? (cause.userInfo[NSLocalizedDescriptionKey] as? String) ?? ""
        let message: String
        switch code {
        case .quotaExceeded:
            message = "Your iCloud storage is full."
        case .notAuthenticated:
            message = "You're signed out of iCloud."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            message = "iCloud couldn't be reached. Sync will retry on its own."
        case .accountTemporarilyUnavailable:
            message = "Your iCloud account needs attention in the Settings app."
        case .incompatibleVersion:
            message = "A newer version of Palettes is needed to sync this library."
        default:
            // "Cannot create new type … in production schema", "Unknown field …":
            // this build writes something the live CloudKit schema doesn't have.
            let schemaWords = ["production schema", "record type", "unknown field", "cannot create"]
            let lowered = server.lowercased()
            if schemaWords.contains(where: { lowered.contains($0) }) {
                message = "iCloud isn't set up for this version of Palettes yet."
            } else {
                message = server.isEmpty ? cause.localizedDescription : server
            }
        }
        return "\(message) (CloudKit error \(cause.code))"
    }

    /// For a partial failure, the per-record error seen most often, ignoring
    /// the records that only failed because their batch did.
    static func underlyingCause(of error: NSError) -> NSError {
        guard error.domain == CKErrorDomain,
              error.code == CKError.Code.partialFailure.rawValue,
              let partial = error.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] else {
            return error
        }
        let causes = partial.values.map { $0 as NSError }.filter {
            !($0.domain == CKErrorDomain && $0.code == CKError.Code.batchRequestFailed.rawValue)
        }
        let byCode = Dictionary(grouping: causes, by: \.code)
        let commonest = byCode.max { a, b in
            a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key
        }
        return commonest?.value.first ?? error
    }

    // MARK: Schema

    #if DEBUG
    /// Launch a debug build once with this argument (signed in to iCloud, sync
    /// on) to write every record type and field to the CloudKit *development*
    /// schema, ready to be deployed to production in the CloudKit Console.
    /// Without it the development schema only learns a type the first time a
    /// record of it happens to sync, so types nobody created in a debug build
    /// never reach production, and release builds then fail every export.
    static let initializeSchemaArgument = "-initCloudKitSchema"
    static let containerIdentifier = "iCloud.com.halilbagosi.Palettes"

    /// Opens the synced store through Core Data just long enough to push the
    /// schema, then lets go of it before SwiftData opens the same file.
    static func initializeCloudKitSchema() {
        let description = NSPersistentStoreDescription(url: cloudStoreURL)
        description.cloudKitContainerOptions =
            NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
        description.shouldAddStoreAsynchronously = false
        guard let model = NSManagedObjectModel.makeManagedObjectModel(
            for: [StoredColor.self, StoredPalette.self, StoredTag.self]) else {
            logger.error("CloudKit schema: couldn't build the object model")
            return
        }
        let container = NSPersistentCloudKitContainer(name: "Palettes", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        do {
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            logger.notice("CloudKit schema: development schema initialized")
        } catch {
            logger.error("CloudKit schema: \(String(describing: error), privacy: .public)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
    }
    #endif
}
