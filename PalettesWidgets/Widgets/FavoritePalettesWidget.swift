//
//  FavoritePalettesWidget.swift
//  PalettesWidgets
//
//  Up to five favorite palettes (three in medium) as strips. Each row opens its palette.
//

import SwiftUI
import WidgetKit

struct FavoritePalettesEntry: TimelineEntry {
    let date: Date
    let palettes: [WidgetSnapshot.Palette]
}

struct FavoritePalettesProvider: AppIntentTimelineProvider {
    static func capacity(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 5 : 3
    }

    private func entry(for configuration: FavoritePalettesIntent, snapshot: WidgetSnapshot, family: WidgetFamily) -> FavoritePalettesEntry {
        FavoritePalettesEntry(date: .now, palettes: FavoritesSelection.palettes(
            useChosen: configuration.mode == .chosen,
            chosenIDs: (configuration.palettes ?? []).map(\.id),
            in: snapshot,
            capacity: Self.capacity(for: family)))
    }

    private func sampleEntry(family: WidgetFamily) -> FavoritePalettesEntry {
        FavoritePalettesEntry(date: .now, palettes: Array(WidgetSample.snapshot.favoritePalettes.prefix(Self.capacity(for: family))))
    }

    func placeholder(in context: Context) -> FavoritePalettesEntry {
        sampleEntry(family: context.family)
    }

    func snapshot(for configuration: FavoritePalettesIntent, in context: Context) async -> FavoritePalettesEntry {
        let real = entry(for: configuration, snapshot: WidgetSnapshotStore.read(), family: context.family)
        return context.isPreview && real.palettes.isEmpty ? sampleEntry(family: context.family) : real
    }

    /// Redrawn when the app reloads timelines after a library change.
    func timeline(for configuration: FavoritePalettesIntent, in context: Context) async -> Timeline<FavoritePalettesEntry> {
        Timeline(entries: [entry(for: configuration, snapshot: WidgetSnapshotStore.read(), family: context.family)], policy: .never)
    }
}

struct FavoritePalettesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FavoritePalettesWidget", intent: FavoritePalettesIntent.self, provider: FavoritePalettesProvider()) { entry in
            FavoritePalettesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite Palettes")
        .description("Your favorite palettes, or ones you pick.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct FavoritePalettesView: View {
    let entry: FavoritePalettesEntry
    @Environment(\.widgetFamily) private var family

    private var isMedium: Bool { family == .systemMedium }

    var body: some View {
        if entry.palettes.isEmpty {
            EmptyWidgetView(message: "Favorite a palette to see it here")
        } else {
            VStack(alignment: .leading, spacing: isMedium ? 6 : 10) {
                ForEach(entry.palettes) { palette in
                    Link(destination: WidgetLink.palette(palette.id).url) {
                        VStack(alignment: .leading, spacing: isMedium ? 2 : 4) {
                            SwatchStrip(hexes: palette.hexCodes)
                                .frame(minHeight: isMedium ? 14 : 18, maxHeight: isMedium ? 24 : 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(palette.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
            // Top-aligned without a trailing Spacer, which would cost a row gap.
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
