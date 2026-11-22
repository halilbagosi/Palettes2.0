//
//  FavoriteColorsWidget.swift
//  PalettesWidgets
//
//  Favorite colors as tiles: a 2x2 grid (small), a row of four (medium) or a
//  2x3 grid (large). Medium and large tiles open their color; small opens
//  the Colors tab. Shows the favorites, or colors chosen in Edit Widget.
//

import SwiftUI
import WidgetKit

struct FavoriteColorsEntry: TimelineEntry {
    let date: Date
    let colors: [WidgetSnapshot.Swatch]
}

struct FavoriteColorsProvider: AppIntentTimelineProvider {
    static func capacity(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 6 : 4
    }

    private func entry(for configuration: FavoriteColorsIntent, snapshot: WidgetSnapshot, family: WidgetFamily) -> FavoriteColorsEntry {
        FavoriteColorsEntry(date: .now, colors: FavoritesSelection.colors(
            useChosen: configuration.mode == .chosen,
            chosenIDs: (configuration.colors ?? []).map(\.id),
            in: snapshot,
            capacity: Self.capacity(for: family)))
    }

    private func sampleEntry(family: WidgetFamily) -> FavoriteColorsEntry {
        FavoriteColorsEntry(date: .now, colors: Array(WidgetSample.favoriteColorsSnapshot.favoriteColors.prefix(Self.capacity(for: family))))
    }

    func placeholder(in context: Context) -> FavoriteColorsEntry {
        sampleEntry(family: context.family)
    }

    func snapshot(for configuration: FavoriteColorsIntent, in context: Context) async -> FavoriteColorsEntry {
        let real = entry(for: configuration, snapshot: WidgetSnapshotStore.read(), family: context.family)
        return context.isPreview && real.colors.isEmpty ? sampleEntry(family: context.family) : real
    }

    /// Redrawn when the app reloads timelines after a library change.
    func timeline(for configuration: FavoriteColorsIntent, in context: Context) async -> Timeline<FavoriteColorsEntry> {
        Timeline(entries: [entry(for: configuration, snapshot: WidgetSnapshotStore.read(), family: context.family)], policy: .never)
    }
}

struct FavoriteColorsWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "FavoriteColorsWidget", intent: FavoriteColorsIntent.self, provider: FavoriteColorsProvider()) { entry in
            FavoriteColorsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite Colors")
        .description("Your favorite colors, or ones you pick.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct FavoriteColorsView: View {
    let entry: FavoriteColorsEntry
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }
    private var columns: Int { family == .systemMedium ? 4 : 2 }
    private var rows: Int { family == .systemMedium ? 1 : family == .systemLarge ? 3 : 2 }

    var body: some View {
        if entry.colors.isEmpty {
            EmptyWidgetView(message: "Favorite a color to see it here", link: .colors)
        } else if isSmall {
            grid
                // Small widgets have one tap target, so tiles can't be Links.
                .widgetURL(WidgetLink.favoriteColors.url)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Favorite colors: " + entry.colors.map(\.name).joined(separator: ", "))
        } else {
            grid
        }
    }

    private var grid: some View {
        VStack(spacing: isSmall ? 6 : 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: isSmall ? 6 : 8) {
                    ForEach(0..<columns, id: \.self) { column in
                        slot(row * columns + column)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func slot(_ index: Int) -> some View {
        if entry.colors.indices.contains(index) {
            if isSmall { smallTile(entry.colors[index]) } else { tile(entry.colors[index]) }
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Colors only, no text: small tiles are too tight for names.
    private func smallTile(_ swatch: WidgetSnapshot.Swatch) -> some View {
        SwatchStrip(hexes: [swatch.hex])
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tile(_ swatch: WidgetSnapshot.Swatch) -> some View {
        Link(destination: WidgetLink.color(swatch.id).url) {
            ZStack(alignment: .bottomLeading) {
                SwatchStrip(hexes: [swatch.hex])
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(swatch.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(swatch.hex.uppercased())
                        .font(.caption2.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .opacity(0.8)
                }
                .foregroundStyle(Color.widgetForeground(onLight: HexRGB.isLight(swatch.hex)))
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(swatch.name), \(swatch.hex.uppercased())")
    }
}
