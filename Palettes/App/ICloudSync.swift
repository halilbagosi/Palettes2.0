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
}

