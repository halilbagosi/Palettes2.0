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

@available(iOS 26.0, *)
enum EntityIndexer {
    /// Replaces the app's Spotlight entities with the current library.
    /// Fire-and-forget: indexing failures are non-fatal and silent.
    static func reindex(palettes: [PaletteEntity], colors: [ColorEntity]) {
        Task.detached(priority: .background) {
            let index = CSSearchableIndex.default()
            try? await index.deleteAppEntities(ofType: PaletteEntity.self)
            try? await index.deleteAppEntities(ofType: ColorEntity.self)
            try? await index.indexAppEntities(palettes)
            try? await index.indexAppEntities(colors)
        }
    }
}
