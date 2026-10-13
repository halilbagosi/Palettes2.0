import Foundation

/// Single source of truth for matching the library against a free-text term.
/// Shared by `SearchView`, `SearchMatching`, the App Intents and the entity queries.
enum LibrarySearch {

    /// Trimmed term, and the same term without a leading "#" for hex matching.
    static func normalize(_ term: String?) -> (query: String, hexQuery: String) {
        let query = (term ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hexQuery = query.hasPrefix("#") ? String(query.dropFirst()) : query
        return (query, hexQuery)
    }

    /// Hue words ("blue", "blues", "warm", "cool", ...) a query can name.
    static func hueCategories(forWord word: String) -> Set<HueCategory> {
        let w = word.lowercased()
        switch w {
        case "warm": return [.reds, .oranges, .yellows, .pinks]
        case "cool": return [.greens, .blues, .purples]
        default: break
        }
        return Set(HueCategory.allCases.filter {
            let plural = $0.rawValue.lowercased()
            return w == plural || w == String(plural.dropLast())
        })
    }

    static func colorMatches(_ color: ColorViewModel, query: String, hexQuery: String) -> Bool {
        guard !query.isEmpty else { return false }
        if color.name.localizedCaseInsensitiveContains(query) { return true }
        if !hexQuery.isEmpty, color.HEX.localizedCaseInsensitiveContains(hexQuery) { return true }
        let hues = hueCategories(forWord: query)
        return !hues.isEmpty && hues.contains(color.color.hueCategory)
    }

    static func paletteMatches(_ palette: PaletteViewModel, query: String, hexQuery: String) -> Bool {
        guard !query.isEmpty else { return false }
        return palette.name.localizedCaseInsensitiveContains(query) ||
            palette.paletteColors.contains { $0.name.localizedCaseInsensitiveContains(query) } ||
            (!hexQuery.isEmpty && palette.hexCodes.contains { $0.localizedCaseInsensitiveContains(hexQuery) }) ||
            palette.paletteColors.contains { color in
                guard let role = color.role, !role.isEmpty else { return false }
                return role.localizedCaseInsensitiveContains(query)
            }
    }

    /// An empty or nil term returns everything.
    static func colors(matching term: String?, in colors: [ColorViewModel]) -> [ColorViewModel] {
        let (query, hexQuery) = normalize(term)
        guard !query.isEmpty else { return colors }
        return colors.filter { colorMatches($0, query: query, hexQuery: hexQuery) }
    }

    /// An empty or nil term returns everything.
    static func palettes(matching term: String?, in palettes: [PaletteViewModel]) -> [PaletteViewModel] {
        let (query, hexQuery) = normalize(term)
        guard !query.isEmpty else { return palettes }
        return palettes.filter { paletteMatches($0, query: query, hexQuery: hexQuery) }
    }
}
