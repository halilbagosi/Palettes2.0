//
//  WidgetSnapshot.swift
//  Palettes (app + widgets)
//
//  The widgets' read-only copy of the library. The app writes it to the
//  App Group container (see WidgetSnapshotWriter); the extension never
//  opens the SwiftData store.
//

import Foundation
import os

nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let empty = WidgetSnapshot()

    var version: Int = WidgetSnapshot.currentVersion
    /// Library order.
    var palettes: [Palette] = []
    /// Library order.
    var colors: [Swatch] = []

    nonisolated struct Palette: Codable, Equatable, Identifiable, Sendable {
        var id: UUID
        var name: String
        var hexCodes: [String]
        var isFavorite: Bool
    }

    nonisolated struct Swatch: Codable, Equatable, Identifiable, Sendable {
        var id: UUID
        var name: String
        var hex: String
        var isFavorite: Bool
    }

    var favoritePalettes: [Palette] { palettes.filter(\.isFavorite) }

    /// What an unconfigured Color widget shows: the first favorite colour,
    /// else the first colour.
    var defaultColor: Swatch? { colors.first(where: \.isFavorite) ?? colors.first }

    func palette(id: UUID) -> Palette? { palettes.first { $0.id == id } }
    func color(id: UUID) -> Swatch? { colors.first { $0.id == id } }
}

nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.com.halilbagosi.Palettes"
    static let fileName = "widget-snapshot.json"

    private static let log = Logger(subsystem: "com.halilbagosi.Palettes", category: "WidgetSnapshot")

    static var defaultURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    /// Missing, unreadable, corrupt or other-version files all read as empty.
    static func read(from url: URL? = defaultURL) -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url) else { return .empty }
        return decode(data)
    }

    static func decode(_ data: Data) -> WidgetSnapshot {
        guard let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.version == WidgetSnapshot.currentVersion
        else { return .empty }
        return snapshot
    }

    /// Logs that the App Group container can't be resolved (the app or
    /// extension lacks the group entitlement). Callers do it once, not per write.
    static func logMissingContainer() {
        log.error("App Group container unavailable; widget snapshot can't be shared")
    }

    /// Atomic write. False (and logged) on failure; the caller retries on
    /// its next change.
    @discardableResult
    static func write(_ snapshot: WidgetSnapshot, to url: URL? = defaultURL) -> Bool {
        guard let url else { return false }
        do {
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
            return true
        } catch {
            log.error("Widget snapshot write failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
