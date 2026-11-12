//
//  QuickCreateWidget.swift
//  PalettesWidgets
//
//  Two round + buttons: New Color and New Palette.
//

import AppIntents
import SwiftUI
import WidgetKit

struct QuickCreateEntry: TimelineEntry {
    let date: Date
}

struct QuickCreateProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickCreateEntry { QuickCreateEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (QuickCreateEntry) -> Void) {
        completion(QuickCreateEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickCreateEntry>) -> Void) {
        completion(Timeline(entries: [QuickCreateEntry(date: .now)], policy: .never))
    }
}

struct QuickCreateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickCreateWidget", provider: QuickCreateProvider()) { _ in
            QuickCreateEntryView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Create")
        .description("Start a new color or palette.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct QuickCreateEntryView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
            }
            .accessibilityLabel("New Color")
            .widgetURL(WidgetLink.newColor.url)
        } else {
            QuickCreateView()
        }
    }
}

struct QuickCreateView: View {
    var body: some View {
        HStack(spacing: 12) {
            button("New Color", link: .newColor)
            button("New Palette", link: .newPalette)
        }
    }

    /// A Button, not a Link: small widgets ignore Links.
    private func button(_ title: String, link: WidgetLink) -> some View {
        Button(intent: OpenLinkIntent(link)) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 48, height: 48)
                    .background(.background, in: Circle())
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
