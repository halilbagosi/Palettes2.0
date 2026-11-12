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
}

struct ColorProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ColorEntry { ColorEntry(date: .now, swatch: WidgetSample.color) }

    func snapshot(for configuration: ColorWidgetIntent, in context: Context) async -> ColorEntry {
        let entry = makeEntry(for: configuration, snapshot: WidgetSnapshotStore.read())
        if context.isPreview, entry.swatch == nil { return placeholder(in: context) }
        return entry
    }

    func timeline(for configuration: ColorWidgetIntent, in context: Context) async -> Timeline<ColorEntry> {
        Timeline(entries: [makeEntry(for: configuration, snapshot: WidgetSnapshotStore.read())], policy: .never)
    }

    func makeEntry(for configuration: ColorWidgetIntent, snapshot: WidgetSnapshot) -> ColorEntry {
        let chosen = configuration.color.flatMap { snapshot.color(id: $0.id) }
        return ColorEntry(date: .now, swatch: chosen ?? snapshot.defaultColor)
    }
}

struct ColorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ColorWidget", intent: ColorWidgetIntent.self, provider: ColorProvider()) { entry in
            ColorWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Color")
        .description("Keep a color you love in view.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
            EmptyWidgetView(message: "Add a color to see it here")
        }
    }
}
