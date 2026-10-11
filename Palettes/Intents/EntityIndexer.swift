//
//  EntityIndexer.swift
//  Palettes
//
//  Donates the library to Spotlight so Siri / Apple Intelligence can
//  semantically resolve palettes and colors by name.
//

import AppIntents
import CoreSpotlight
import Foundation
import os

@available(iOS 26.0, *)
enum EntityIndexer {
    /// Newest snapshot waiting to be applied; replaced (coalesced) by each
    /// `reindex` call while a job is running.
    @MainActor private static var pending: (palettes: [PaletteEntity], colors: [ColorEntity])?
    @MainActor private static var worker: Task<Void, Never>?

    /// Performs one replace-all pass. A seam so tests can observe ordering
    /// without touching the real Spotlight index.
    @MainActor static var applier: ([PaletteEntity], [ColorEntity]) async -> Void = applyToSpotlight

    @MainActor static var isIdle: Bool { worker == nil }

    /// Replaces the app's Spotlight entities with this snapshot. Jobs run one
    /// at a time and only the newest pending snapshot is applied next, so an
    /// older snapshot can never land after a newer one (e.g. re-adding a
    /// palette the user just deleted).
    @MainActor
    static func reindex(palettes: [PaletteEntity], colors: [ColorEntity]) {
        pending = (palettes, colors)
        guard worker == nil else { return }
        worker = Task { @MainActor in
            while let next = pending {
                pending = nil
                await applier(next.palettes, next.colors)
            }
            worker = nil
        }
    }

    /// Removes every palette and color entity (used by "Delete All Data").
    @MainActor
    static func removeAll() {
        reindex(palettes: [], colors: [])
    }

    private static func applyToSpotlight(_ palettes: [PaletteEntity], _ colors: [ColorEntity]) async {
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAppEntities(ofType: PaletteEntity.self)
            try await index.deleteAppEntities(ofType: ColorEntity.self)
            if !palettes.isEmpty { try await index.indexAppEntities(palettes) }
            if !colors.isEmpty { try await index.indexAppEntities(colors) }
        } catch {
            // Non-fatal: the next library change retries. Type name only, so
            // no palette or color names reach the log.
            Logger(subsystem: "com.halilbagosi.Palettes", category: "spotlight")
                .error("Spotlight reindex failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
