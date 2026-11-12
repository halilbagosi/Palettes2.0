//
//  FavoriteColorsWidget.swift
//  PalettesWidgets
//
//  Favorite colors as tiles: a row of four (medium) or a 2x3 grid (large).
//  Each tile opens its color.
//

import SwiftUI
import WidgetKit

struct FavoriteColorsEntry: TimelineEntry {
    let date: Date
    let colors: [WidgetSnapshot.Swatch]
}

struct FavoriteColorsProvider: TimelineProvider {
    private func capacity(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 6 : 4
    }

    private func entry(from snapshot: WidgetSnapshot, family: WidgetFamily) -> FavoriteColorsEntry {
        FavoriteColorsEntry(date: .now, colors: Array(snapshot.favoriteColors.prefix(capacity(for: family))))
    }

    func placeholder(in context: Context) -> FavoriteColorsEntry {
        entry(from: WidgetSample.favoriteColorsSnapshot, family: context.family)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoriteColorsEntry) -> Void) {
        let real = entry(from: WidgetSnapshotStore.read(), family: context.family)
        completion(context.isPreview && real.colors.isEmpty
                   ? entry(from: WidgetSample.favoriteColorsSnapshot, family: context.family)
                   : real)
    }

    /// Redrawn when the app reloads timelines after a library change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteColorsEntry>) -> Void) {
        completion(Timeline(entries: [entry(from: WidgetSnapshotStore.read(), family: context.family)], policy: .never))
    }
}

struct FavoriteColorsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FavoriteColorsWidget", provider: FavoriteColorsProvider()) { entry in
            FavoriteColorsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite Colors")
        .description("Your favorite colors at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct FavoriteColorsView: View {
    let entry: FavoriteColorsEntry
    @Environment(\.widgetFamily) private var family

    private var columns: Int { family == .systemLarge ? 2 : 4 }
    private var rows: Int { family == .systemLarge ? 3 : 1 }

    var body: some View {
        if entry.colors.isEmpty {
            EmptyWidgetView(message: "Favorite a color to see it here")
        } else {
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<columns, id: \.self) { column in
                            slot(row * columns + column)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func slot(_ index: Int) -> some View {
        if entry.colors.indices.contains(index) {
            tile(entry.colors[index])
        } else {
            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                    Text(swatch.hex.uppercased())
                        .font(.caption2.monospaced())
                        .opacity(0.8)
                }
                .foregroundStyle(Color.widgetForeground(onLight: HexRGB.isLight(swatch.hex)))
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(swatch.name), \(swatch.hex)")
    }
}
