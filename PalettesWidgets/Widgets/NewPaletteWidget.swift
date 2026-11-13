//
//  NewPaletteWidget.swift
//  PalettesWidgets
//
//  One tap to start a palette. Small: a fan of swatch cards in one of
//  `CreateArt.palettes`, a different one each day, with a + and "New
//  Palette". Lock Screen circular: a palette symbol on the accessory
//  background.
//

import AppIntents
import SwiftUI
import WidgetKit

struct NewPaletteEntry: TimelineEntry {
    let date: Date
    let hexes: [String]
}

struct NewPaletteProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewPaletteEntry {
        NewPaletteEntry(date: .now, hexes: CreateArt.palettes[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (NewPaletteEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NewPaletteEntry>) -> Void) {
        let entries = WidgetRotation.dayDates(from: .now, calendar: .current).map(entry(at:))
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> NewPaletteEntry {
        let day = WidgetRotation.dayIndex(at: date, calendar: .current)
        return NewPaletteEntry(date: date, hexes: CreateArt.palette(forDay: day))
    }
}

struct NewPaletteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewPaletteWidget", provider: NewPaletteProvider()) { entry in
            NewPaletteEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("New Palette")
        .description("Start a new palette.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct NewPaletteEntryView: View {
    let entry: NewPaletteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "swatchpalette")
                    .font(.title3.weight(.semibold))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("New Palette")
            .widgetURL(WidgetLink.newPalette.url)
        } else {
            // A Button, not a Link: small widgets ignore Links.
            Button(intent: OpenLinkIntent(.newPalette)) {
                NewPaletteFace(hexes: entry.hexes)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Palette")
            .accessibilityHint("Opens Palettes")
        }
    }
}
