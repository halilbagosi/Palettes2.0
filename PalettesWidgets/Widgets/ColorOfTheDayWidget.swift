//
//  ColorOfTheDayWidget.swift
//  PalettesWidgets
//
//  A different color from the library each day.
//

import SwiftUI
import WidgetKit

struct ColorOfTheDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> ColorEntry { ColorEntry(date: .now, swatch: WidgetSample.color) }

    func getSnapshot(in context: Context, completion: @escaping (ColorEntry) -> Void) {
        let swatch = WidgetRotation.colorOfTheDay(in: WidgetSnapshotStore.read(), at: .now)
        completion(context.isPreview && swatch == nil ? placeholder(in: context) : ColorEntry(date: .now, swatch: swatch))
    }

    /// Today's color, then tomorrow's at midnight.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ColorEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        let entries = WidgetRotation.dayDates(from: .now, calendar: .current).map { date in
            ColorEntry(date: date, swatch: WidgetRotation.colorOfTheDay(in: snapshot, at: date))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ColorOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ColorOfTheDayWidget", provider: ColorOfTheDayProvider()) { entry in
            ColorOfTheDayView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Color of the Day")
        .description("A different color from your library every day.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct ColorOfTheDayView: View {
    let entry: ColorEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let swatch = entry.swatch {
            ColorFace(swatch: swatch, family: family, caption: "Today", copied: entry.copiedID == swatch.id)
                .widgetURL(WidgetLink.color(swatch.id).url)
        } else {
            EmptyWidgetView(message: "Add a color to see it here")
        }
    }
}
