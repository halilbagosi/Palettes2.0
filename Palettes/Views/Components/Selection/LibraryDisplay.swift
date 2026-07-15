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

enum LibrarySort: String, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestFirst: "Newest First"
        case .oldestFirst: "Oldest First"
        }
    }

    var systemImage: String {
        switch self {
        case .newestFirst: "arrow.down"
        case .oldestFirst: "arrow.up"
        }
    }
}
