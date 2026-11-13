//
//  WidgetSnapshotWriter.swift
//  Palettes
//
//  Keeps the widgets' snapshot (WidgetSnapshot) in step with AppData's
//  library, and asks WidgetKit to redraw when it changes. Owned by AppData;
//  nothing else writes the snapshot.
//

import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotWriter {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    private let url: URL?
    private let reload: () -> Void
    /// The last snapshot that reached disk; nil until one does, so a failed
    /// write is retried on the next update.
    private var lastWritten: WidgetSnapshot?

    init(
        url: URL? = WidgetSnapshotStore.defaultURL,
        reload: @escaping () -> Void = { WidgetCenter.shared.reloadAllTimelines() }
    ) {
        self.url = url
        if url == nil { WidgetSnapshotStore.logMissingContainer() }
        self.reload = reload
    }

    static func snapshot(palettes: [PaletteViewModel], colors: [ColorViewModel]) -> WidgetSnapshot {
        WidgetSnapshot(
            palettes: palettes.map {
                .init(id: $0.id, name: $0.name, hexCodes: $0.hexCodes, colorNames: $0.colorNames, isFavorite: $0.isFavorite)
            },
            colors: colors.map {
                .init(id: $0.id, name: $0.name, hex: $0.HEX, isFavorite: $0.isFavorite)
            }
        )
    }

    /// Writes and reloads timelines when the snapshot differs from the last
    /// one written. True when it wrote.
    @discardableResult
    func update(palettes: [PaletteViewModel], colors: [ColorViewModel]) -> Bool {
        let snapshot = Self.snapshot(palettes: palettes, colors: colors)
        guard snapshot != lastWritten, WidgetSnapshotStore.write(snapshot, to: url) else { return false }
        lastWritten = snapshot
        reload()
        return true
    }
}
