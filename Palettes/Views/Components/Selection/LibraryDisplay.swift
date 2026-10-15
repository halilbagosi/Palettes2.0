//
//  LibraryDisplay.swift
//  Palettes
//
//  Display preferences shared by the Palettes and Colors libraries. Sorting and
//  filtering are applied only when building the on-screen collection, never to
//  the stored arrays, so creation order (== insertion order) stays intact.
//

import SwiftUI

enum ListLayout: String {
    case normal
    case compact
}

enum LibraryOriginFilter: String, CaseIterable, Identifiable {
    case all
    case created
    case generated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .created: "Created"
        case .generated: "Generated"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .created: "plus.circle"
        case .generated: "sparkles"
        }
    }

    func includes(isGenerated: Bool) -> Bool {
        switch self {
        case .all: true
        case .created: !isGenerated
        case .generated: isGenerated
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst
    /// Around the color wheel, red first; see `HueOrder`. The raw value is the
    /// old single "hue" sort, so a saved choice keeps meaning the same thing.
    case hueAscending = "hue"
    /// Around the color wheel, backwards.
    case hueDescending

    var id: String { rawValue }

    /// The sorts the Palettes tab offers: everything except hue order.
    static let paletteCases: [LibrarySort] = [.newestFirst, .oldestFirst]

    var label: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        case .hueAscending: "Hue, Ascending"
        case .hueDescending: "Hue, Descending"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst: "arrow.down"
        case .oldestFirst: "arrow.up"
        case .hueAscending, .hueDescending: "rainbow"
        }
    }

    /// The icon shown beside the label: the hue symbol with an arrow for the
    /// two hue sorts, the plain symbol otherwise.
    var icon: Image {
        switch self {
        case .newestFirst, .oldestFirst: Image(systemName: systemImage)
        case .hueAscending: Self.hueIcon(arrow: "arrow.up")
        case .hueDescending: Self.hueIcon(arrow: "arrow.down")
        }
    }

    /// Menus draw one image per item, so the rainbow and the arrow are
    /// composed into a single template image.
    private static func hueIcon(arrow: String) -> Image {
        let config = UIImage.SymbolConfiguration(scale: .medium)
        guard let rainbow = UIImage(systemName: "rainbow", withConfiguration: config),
              let arrow = UIImage(systemName: arrow, withConfiguration: config) else {
            return Image(systemName: "rainbow")
        }
        let gap: CGFloat = 2
        let size = CGSize(width: rainbow.size.width + gap + arrow.size.width,
                          height: max(rainbow.size.height, arrow.size.height))
        let composed = UIGraphicsImageRenderer(size: size).image { _ in
            rainbow.withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(at: CGPoint(x: 0, y: (size.height - rainbow.size.height) / 2))
            arrow.withTintColor(.black, renderingMode: .alwaysOriginal)
                .draw(at: CGPoint(x: rainbow.size.width + gap, y: (size.height - arrow.size.height) / 2))
        }
        return Image(uiImage: composed.withRenderingMode(.alwaysTemplate))
    }

    /// `items` (in creation order) in this sort's order. `hueKey` is read
    /// once per item, and only for the hue sorts.
    func ordered<Item>(_ items: [Item], hueKey: (Item) -> HueOrder.Key) -> [Item] {
        switch self {
        case .newestFirst:
            return items.reversed()
        case .oldestFirst:
            return items
        case .hueAscending:
            return hueOrdered(items, hueKey: hueKey)
        case .hueDescending:
            return hueOrdered(items, hueKey: hueKey).reversed()
        }
    }
}

private func hueOrdered<Item>(_ items: [Item], hueKey: (Item) -> HueOrder.Key) -> [Item] {
    items.map { (key: hueKey($0), item: $0) }
        .sorted { $0.key < $1.key }
        .map(\.item)
}

/// The library's title. Before iOS 26 the number of items on screen goes in
/// front: "12 Palettes", "1 Color"; just the plural when there are none.
/// From iOS 26 the count sits in a capsule beside the plural (LargeTitleCompat).
enum LibraryTitle {
    static func text(_ noun: String, count: Int) -> String {
        switch count {
        case 0: "\(noun)s"
        case 1: "1 \(noun)"
        default: "\(count) \(noun)s"
        }
    }

    static func plural(_ noun: String) -> String { "\(noun)s" }
}
