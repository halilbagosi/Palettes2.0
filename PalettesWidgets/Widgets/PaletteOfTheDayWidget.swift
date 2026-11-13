//
//  PaletteOfTheDayWidget.swift
//  PalettesWidgets
//
//  A different palette from the library each day. Medium: the Palette
//  widget's bands. Large: bands on top, then a row per color with its name and hex.
//

import SwiftUI
import WidgetKit

struct PaletteOfTheDayProvider: TimelineProvider {
    static let emptyMessage = "Create a palette to see it here"

    func placeholder(in context: Context) -> PaletteEntry { PaletteEntry(date: .now, palette: WidgetSample.palette) }

    func getSnapshot(in context: Context, completion: @escaping (PaletteEntry) -> Void) {
        let palette = WidgetRotation.paletteOfTheDay(in: WidgetSnapshotStore.read(), at: .now)
        completion(context.isPreview && palette == nil ? placeholder(in: context) : PaletteEntry(date: .now, palette: palette, emptyMessage: Self.emptyMessage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PaletteEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read()
        let entries = WidgetRotation.dayDates(from: .now, calendar: .current).map { date in
            PaletteEntry(date: date, palette: WidgetRotation.paletteOfTheDay(in: snapshot, at: date),
                         emptyMessage: Self.emptyMessage)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct PaletteOfTheDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PaletteOfTheDayWidget", provider: PaletteOfTheDayProvider()) { entry in
            PaletteOfTheDayView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Palette of the Day")
        .description("A different palette from your library every day.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct PaletteOfTheDayView: View {
    let entry: PaletteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let palette = entry.palette {
            Group {
                if family == .systemLarge {
                    PaletteListFace(palette: palette, caption: "Today")
                } else {
                    PaletteFace(palette: palette, caption: "Today")
                }
            }
            .widgetURL(WidgetLink.palette(palette.id).url)
        } else {
            EmptyWidgetView(message: entry.emptyMessage)
        }
    }
}
