//
//  LibraryDisplay.swift
//  Palettes
//
//  Display preferences shared by the Palettes and Colors libraries. Sorting and
//  filtering are applied only when building the on-screen collection, never to
//  the stored arrays, so creation order (== insertion order) stays intact.
//

import Foundation

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
    /// Around the color wheel; see `HueOrder`.
    case hue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        case .hue: "Hue"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst: "arrow.down"
        case .oldestFirst: "arrow.up"
        case .hue: "rainbow"
        }
    }

    /// `items` (in creation order) in this sort's order. `hueKey` is read
    /// once per item, and only for `.hue`.
    func ordered<Item>(_ items: [Item], hueKey: (Item) -> HueOrder.Key) -> [Item] {
        switch self {
        case .newestFirst:
            return items.reversed()
        case .oldestFirst:
            return items
        case .hue:
            return items.map { (key: hueKey($0), item: $0) }
                .sorted { $0.key < $1.key }
                .map(\.item)
        }
    }
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
