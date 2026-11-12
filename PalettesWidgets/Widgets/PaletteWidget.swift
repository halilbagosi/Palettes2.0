//
//  PaletteWidget.swift
//  PalettesWidgets
//
//  One palette as vertical bands: a chosen one, or a different favorite
//  each hour.
//

import SwiftUI
import WidgetKit

struct PaletteEntry: TimelineEntry {
    let date: Date
    let palette: WidgetSnapshot.Palette?
    var emptyMessage: String = "Favorite a palette to see it here"
    var copiedID: UUID? = nil
}

struct PaletteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PaletteEntry {
        PaletteEntry(date: .now, palette: WidgetSample.palette)
    }

    func snapshot(for configuration: PaletteWidgetIntent, in context: Context) async -> PaletteEntry {
        let entry = makeEntries(for: configuration, snapshot: WidgetSnapshotStore.read(), now: .now)[0]
        if context.isPreview, entry.palette == nil { return placeholder(in: context) }
        return entry
    }

    func timeline(for configuration: PaletteWidgetIntent, in context: Context) async -> Timeline<PaletteEntry> {
        let items = makeEntries(for: configuration, snapshot: WidgetSnapshotStore.read(), now: .now)
        return Timeline(entries: items, policy: configuration.mode == .rotate ? .atEnd : .never)
    }

    func makeEntries(for configuration: PaletteWidgetIntent, snapshot: WidgetSnapshot, now: Date) -> [PaletteEntry] {
        switch configuration.mode {
        case .specific:
            let palette = configuration.palette.flatMap { snapshot.palette(id: $0.id) }
            return [PaletteEntry(date: now, palette: palette, emptyMessage: "Choose a palette")]
        case .rotate:
            return WidgetRotation.hourlyDates(from: now).map { date in
                PaletteEntry(date: date, palette: WidgetRotation.favoritePalette(in: snapshot, at: date))
            }
        }
    }
}

struct PaletteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PaletteWidget", intent: PaletteWidgetIntent.self, provider: PaletteProvider()) { entry in
            PaletteWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Palette")
        .description("One palette, or your favorites in turn.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct PaletteWidgetView: View {
    let entry: PaletteEntry

    var body: some View {
        if let palette = entry.palette {
            PaletteFace(palette: palette, copied: entry.copiedID == palette.id)
                .widgetURL(WidgetLink.palette(palette.id).url)
        } else {
            EmptyWidgetView(message: entry.emptyMessage)
        }
    }
}
