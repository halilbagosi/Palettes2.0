//
//  ColorWidget.swift
//  PalettesWidgets
//
//  One chosen color filling the widget.
//

import SwiftUI
import WidgetKit

struct ColorEntry: TimelineEntry {
    let date: Date
    let swatch: WidgetSnapshot.Swatch?
    var emptyMessage: String = "Add a color to see it here"
}

struct ColorProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ColorEntry { ColorEntry(date: .now, swatch: WidgetSample.color) }

    func snapshot(for configuration: ColorWidgetIntent, in context: Context) async -> ColorEntry {
        let entry = makeEntries(for: configuration, snapshot: WidgetSnapshotStore.read(), now: .now)[0]
        if context.isPreview, entry.swatch == nil { return placeholder(in: context) }
        return entry
    }

    func timeline(for configuration: ColorWidgetIntent, in context: Context) async -> Timeline<ColorEntry> {
        let items = makeEntries(for: configuration, snapshot: WidgetSnapshotStore.read(), now: .now)
        return Timeline(entries: items, policy: configuration.mode == .rotate ? .atEnd : .never)
    }

    func makeEntries(for configuration: ColorWidgetIntent, snapshot: WidgetSnapshot, now: Date) -> [ColorEntry] {
        switch configuration.mode {
        case .specific:
            let chosen = configuration.color.flatMap { snapshot.color(id: $0.id) }
            return [ColorEntry(date: now, swatch: chosen ?? snapshot.defaultColor)]
        case .rotate:
            return WidgetRotation.hourlyDates(from: now).map { date in
                ColorEntry(
                    date: date,
                    swatch: WidgetRotation.favoriteColor(in: snapshot, at: date),
                    emptyMessage: "Favorite a color to see it here"
                )
            }
        }
    }
}

struct ColorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ColorWidget", intent: ColorWidgetIntent.self, provider: ColorProvider()) { entry in
            ColorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Color")
        .description("One color, or your favorites in turn.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct ColorWidgetView: View {
    let entry: ColorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let swatch = entry.swatch {
            ColorFace(swatch: swatch, family: family)
                .widgetURL(WidgetLink.color(swatch.id).url)
        } else {
            EmptyWidgetView(message: entry.emptyMessage)
        }
    }
}
