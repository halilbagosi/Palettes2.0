//
//  FavoritePalettesWidget.swift
//  PalettesWidgets
//
//  Up to five favorite palettes as strips. Each row opens its palette.
//

import SwiftUI
import WidgetKit

struct FavoritePalettesEntry: TimelineEntry {
    let date: Date
    let palettes: [WidgetSnapshot.Palette]
}

struct FavoritePalettesProvider: TimelineProvider {
    static let maxRows = 5

    private func entry(from snapshot: WidgetSnapshot) -> FavoritePalettesEntry {
        FavoritePalettesEntry(date: .now, palettes: Array(snapshot.favoritePalettes.prefix(Self.maxRows)))
    }

    func placeholder(in context: Context) -> FavoritePalettesEntry { entry(from: WidgetSample.snapshot) }

    func getSnapshot(in context: Context, completion: @escaping (FavoritePalettesEntry) -> Void) {
        let real = entry(from: WidgetSnapshotStore.read())
        completion(context.isPreview && real.palettes.isEmpty ? entry(from: WidgetSample.snapshot) : real)
    }

    /// Redrawn when the app reloads timelines after a library change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritePalettesEntry>) -> Void) {
        completion(Timeline(entries: [entry(from: WidgetSnapshotStore.read())], policy: .never))
    }
}

struct FavoritePalettesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FavoritePalettesWidget", provider: FavoritePalettesProvider()) { entry in
            FavoritePalettesView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite Palettes")
        .description("Your favorite palettes at a glance.")
        .supportedFamilies([.systemLarge])
    }
}

struct FavoritePalettesView: View {
    let entry: FavoritePalettesEntry

    var body: some View {
        if entry.palettes.isEmpty {
            EmptyWidgetView(message: "Favorite a palette to see it here")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(entry.palettes) { palette in
                    Link(destination: WidgetLink.palette(palette.id).url) {
                        VStack(alignment: .leading, spacing: 4) {
                            SwatchStrip(hexes: palette.hexCodes)
                                .frame(minHeight: 18, maxHeight: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(palette.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
