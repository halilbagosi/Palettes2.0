import Foundation

/// Pure, testable matching helpers backing `SearchView`'s search and browse-mode
/// filtering. Kept free of SwiftUI/state so behavior can be verified directly.
enum SearchMatching {

    /// Matches a palette against a free-text search query. Preserves the original
    /// name/colorName/hex predicate and additionally matches a color's tagged role
    /// (e.g. searching "primary" surfaces palettes containing a color tagged Primary).
    static func paletteMatchesQuery(_ palette: PaletteViewModel, query: String, hexQuery: String) -> Bool {
        LibrarySearch.paletteMatches(palette, query: query, hexQuery: hexQuery)
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

/// Library-derived data for Search's browse mode, built once per library change.
/// `hueCategory` resolves through `UIColor`, so the hue of every color and every
/// palette swatch is looked up here rather than on each `SearchView` body run.
struct SearchBrowseIndex {
    private(set) var colorHues: [UUID: HueCategory] = [:]
    private(set) var paletteHues: [UUID: Set<HueCategory>] = [:]
    /// Hues present anywhere in the library, in `HueCategory.allCases` order.
    private(set) var availableHues: [HueCategory] = []
    /// Role tags present in the library's palettes (see `SearchMatching.tagsInUse`).
    private(set) var availableTags: [String] = []

    init() {}

    init(colors: [ColorViewModel], palettes: [PaletteViewModel]) {
        var present = Set<HueCategory>()
        for color in colors {
            let hue = color.color.hueCategory
            colorHues[color.id] = hue
            present.insert(hue)
        }
        for palette in palettes {
            let hues = Set(palette.paletteColors.map { $0.color.hueCategory })
            paletteHues[palette.id] = hues
            present.formUnion(hues)
        }
        availableHues = HueCategory.allCases.filter { present.contains($0) }
        availableTags = SearchMatching.tagsInUse(palettes: palettes)
    }

    /// Colors whose hue is one of `hues`; an empty set keeps every color.
    func colors(_ colors: [ColorViewModel], hues: Set<HueCategory>) -> [ColorViewModel] {
        guard !hues.isEmpty else { return colors }
        return colors.filter { color in
            hues.contains(colorHues[color.id] ?? color.color.hueCategory)
        }
    }

    /// Palettes with a swatch in one of `hues` and a color tagged with one of `tags`;
    /// an empty set skips that filter.
    func palettes(_ palettes: [PaletteViewModel], hues: Set<HueCategory>, tags: Set<String>) -> [PaletteViewModel] {
        palettes.filter { palette in
            let paletteHues = paletteHues[palette.id] ?? Set(palette.colors.map(\.hueCategory))
            return (hues.isEmpty || !paletteHues.isDisjoint(with: hues)) &&
                SearchMatching.paletteMatchesTags(palette, tags: tags)
        }
    }
}
