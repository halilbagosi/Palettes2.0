//
//  NameLimit.swift
//  Palettes
//
//  The one cap on user-visible names (colors, palettes, custom tags). Names
//  arrive from text fields, Shortcuts, the on-device model and CloudKit sync;
//  the view models clamp on every write so an oversized name can't reach
//  exporters or layout code.
//

import Foundation

enum NameLimit {
    /// Characters (grapheme clusters), not UTF-16 units.
    static let maxLength = 100

    static func clamp(_ name: String) -> String {
        name.count > maxLength ? String(name.prefix(maxLength)) : name
    }
}
