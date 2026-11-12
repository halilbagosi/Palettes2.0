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
                    PaletteOfTheDayLarge(palette: palette)
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

/// Bands across the top half; name, "Today" and one row per color below.
struct PaletteOfTheDayLarge: View {
    let palette: WidgetSnapshot.Palette
    /// The copy button sits on the widget background here, not on a swatch.
    @Environment(\.colorScheme) private var colorScheme

    static let maxRows = 5

    /// All rows when they fit; otherwise four and a "+N more" line.
    private var shownCount: Int {
        palette.hexCodes.count <= Self.maxRows ? palette.hexCodes.count : Self.maxRows - 1
    }

    var body: some View {
        VStack(spacing: 0) {
            SwatchStrip(hexes: palette.hexCodes)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(palette.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("TODAY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<shownCount, id: \.self) { index in
                    row(hex: palette.hexCodes[index], name: name(at: index))
                }
                HStack {
                    if palette.hexCodes.count > shownCount {
                        Text("+\(palette.hexCodes.count - shownCount) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CopyButton(link: .copyPalette(palette.id), onLight: colorScheme == .light)
                }
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// The color's name, or nil when missing or empty.
    private func name(at index: Int) -> String? {
        guard palette.colorNames.indices.contains(index) else { return nil }
        let name = palette.colorNames[index]
        return name.isEmpty ? nil : name
    }

    private func row(hex: String, name: String?) -> some View {
        HStack(spacing: 8) {
            SwatchStrip(hexes: [hex])
                .frame(width: 14, height: 14)
                .clipShape(Circle())
            if let name {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
            }
            Text(hex.uppercased())
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
    }
}
