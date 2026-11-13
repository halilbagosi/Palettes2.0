//
//  NewColorWidget.swift
//  PalettesWidgets
//
//  One tap to add a colour. Small: a luminous field of hues with a + and
//  "New Color". Lock Screen circular: a + on the accessory background.
//

import AppIntents
import SwiftUI
import WidgetKit

struct NewColorEntry: TimelineEntry {
    let date: Date
}

struct NewColorProvider: TimelineProvider {
    func placeholder(in context: Context) -> NewColorEntry { NewColorEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (NewColorEntry) -> Void) {
        completion(NewColorEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NewColorEntry>) -> Void) {
        completion(Timeline(entries: [NewColorEntry(date: .now)], policy: .never))
    }
}

struct NewColorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NewColorWidget", provider: NewColorProvider()) { _ in
            NewColorEntryView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("New Color")
        .description("Add a color to your library.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct NewColorEntryView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("New Color")
            .widgetURL(WidgetLink.newColor.url)
        } else {
            // A Button, not a Link: small widgets ignore Links.
            Button(intent: OpenLinkIntent(.newColor)) {
                NewColorFace()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New Color")
            .accessibilityHint("Opens Palettes")
        }
    }
}
