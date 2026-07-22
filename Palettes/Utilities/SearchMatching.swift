import Foundation

/// Pure, testable matching helpers backing `SearchView`'s search and browse-mode
/// filtering. Kept free of SwiftUI/state so behavior can be verified directly.
enum SearchMatching {

    /// Matches a palette against a free-text search query. Preserves the original
    /// name/colorName/hex predicate and additionally matches a color's tagged role
    /// (e.g. searching "primary" surfaces palettes containing a color tagged Primary).
    static func paletteMatchesQuery(_ palette: PaletteViewModel, query: String, hexQuery: String) -> Bool {
        palette.name.localizedCaseInsensitiveContains(query) ||
        palette.colorNames.contains(where: { $0.localizedCaseInsensitiveContains(query) }) ||
        (!hexQuery.isEmpty && palette.hexCodes.contains(where: { $0.localizedCaseInsensitiveContains(hexQuery) })) ||
        palette.paletteColors.contains(where: { color in
            guard let role = color.role, !role.isEmpty else { return false }
            return role.localizedCaseInsensitiveContains(query)
        })
    }

    /// Any-of, case-insensitive match against a palette's tagged color roles.
    /// An empty `tags` set matches every palette (no filter applied), mirroring
    /// the hue-chip "All" behavior.
    static func paletteMatchesTags(_ palette: PaletteViewModel, tags: Set<String>) -> Bool {
        guard !tags.isEmpty else { return true }
        let lowerTags = Set(tags.map { $0.lowercased() })
        return palette.paletteColors.contains(where: { color in
            guard let role = color.role, !role.isEmpty else { return false }
            return lowerTags.contains(role.lowercased())
        })
    }

    /// All distinct color-role tags present across `palettes`, ordered with
    /// built-in roles first (in `ColorRole.defaults` order) followed by custom
    /// tags sorted alphabetically. Case-insensitive duplicates collapse to a
    /// single entry.
    static func tagsInUse(palettes: [PaletteViewModel]) -> [String] {
        var seen: [String: String] = [:] // lowercased key -> first-seen original casing
        for palette in palettes {
            for color in palette.paletteColors {
                guard let role = color.role, !role.isEmpty else { continue }
                let key = role.lowercased()
                if seen[key] == nil {
                    seen[key] = role
                }
            }
        }

        let defaultNames = ColorRole.defaults.map { $0.name }
        let builtinKeys = Set(defaultNames.map { $0.lowercased() })

        let builtins = defaultNames.filter { seen[$0.lowercased()] != nil }
        let customs = seen.keys
            .filter { !builtinKeys.contains($0) }
            .compactMap { seen[$0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        return builtins + customs
    }
}
