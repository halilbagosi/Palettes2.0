import Foundation

/// A UI/UX role a palette color can be tagged with (one per color).
/// Stored on colors as the plain `name` string; `slug` is derived for exports.
struct ColorRole: Hashable, Identifiable {
    let name: String
    var id: String { name.lowercased() }

    /// Kebab-case identifier, e.g. "Brand Blue 2" → "brand-blue-2".
    var slug: String {
        var result = ""
        for ch in name.lowercased() {
            if ch.isLetter || ch.isNumber { result.append(ch) }
            else if ch == " " || ch == "-" || ch == "_" { result.append("-") }
        }
        while result.contains("--") { result = result.replacingOccurrences(of: "--", with: "-") }
        while result.hasPrefix("-") { result.removeFirst() }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "color" : result
    }

    static let defaults: [ColorRole] = ["Primary", "Secondary", "Accent", "Background",
                                        "Surface", "Text", "Error", "Success", "Warning", "Border"].map(ColorRole.init)
}
