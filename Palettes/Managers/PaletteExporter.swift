//
//  PaletteExporter.swift
//  Palettes
//
//  Coolors-style palette export: code snippets, SVG, ASE, PDF, and share URL.
//

import Foundation
import UIKit

enum PaletteExportFormat: String, CaseIterable, Identifiable {
    case css, scss, swiftui, tailwind, json, plainHex, coolorsURL, svg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .css: return "CSS"
        case .scss: return "SCSS"
        case .swiftui: return "SwiftUI"
        case .tailwind: return "Tailwind"
        case .json: return "JSON"
        case .plainHex: return "Plain HEX"
        case .coolorsURL: return "Coolors URL"
        case .svg: return "SVG"
        }
    }
}

enum PaletteExporter {

    // MARK: - Public API

    static func export(_ palette: PaletteViewModel, as format: PaletteExportFormat) -> String {
        switch format {
        case .css: return cssString(palette)
        case .scss: return scssString(palette)
        case .swiftui: return swiftUIString(palette)
        case .tailwind: return tailwindString(palette)
        case .json: return jsonString(palette)
        case .plainHex: return plainHexString(palette)
        case .coolorsURL: return coolorsURLString(palette)
        case .svg: return svgString(palette)
        }
    }

    // MARK: - Helpers

    /// Safely zips names with hexes; pads missing names with the hex sans `#`.
    private static func namesAndHexes(_ palette: PaletteViewModel) -> [(name: String, hex: String)] {
        let count = palette.hexCodes.count
        var result: [(String, String)] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let hex = palette.hexCodes[i]
            let name: String
            if i < palette.colorNames.count {
                name = palette.colorNames[i]
            } else {
                name = String(hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex))
            }
            result.append((name, hex))
        }
        return result
    }

    private static func slugify(_ name: String) -> String {
        let lowered = name.lowercased()
        var result = ""
        result.reserveCapacity(lowered.count)
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                result.append(ch)
            } else if ch == " " || ch == "-" || ch == "_" {
                result.append("-")
            }
            // else: strip
        }
        // collapse consecutive hyphens
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        // trim leading/trailing hyphens
        while result.hasPrefix("-") { result.removeFirst() }
        while result.hasSuffix("-") { result.removeLast() }
        return result.isEmpty ? "color" : result
    }

    /// Slugifies names, deduplicating collisions with -2, -3 suffixes in order of appearance.
    private static func uniqueSlugs(for names: [String]) -> [String] {
        var seenCounts: [String: Int] = [:]
        var results: [String] = []
        for name in names {
            let base = slugify(name)
            if let count = seenCounts[base] {
                let newCount = count + 1
                seenCounts[base] = newCount
                results.append("\(base)-\(newCount)")
            } else {
                seenCounts[base] = 1
                results.append(base)
            }
        }
        return results
    }

    private static func camelCase(_ slug: String) -> String {
        let parts = slug.split(separator: "-")
        guard let first = parts.first else { return "color" }
        var result = String(first)
        for part in parts.dropFirst() {
            result += part.prefix(1).uppercased() + part.dropFirst()
        }
        return result
    }

    private static func hexComponents(_ hex: String) -> (r: Int, g: Int, b: Int) {
        var cleaned = hex
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count >= 6, let value = UInt32(cleaned.prefix(6), radix: 16) else {
            return (0, 0, 0)
        }
        let r = Int((value >> 16) & 0xFF)
        let g = Int((value >> 8) & 0xFF)
        let b = Int(value & 0xFF)
        return (r, g, b)
    }

    private static func xmlEscape(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        return result
    }

    private static func jsonEscape(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        return result
    }

    // MARK: - Format generators

    private static func cssString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.name })
        var lines = [":root {"]
        for (index, pair) in pairs.enumerated() {
            lines.append("  --\(slugs[index]): \(pair.hex);")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func scssString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.name })
        var lines: [String] = []
        for (index, pair) in pairs.enumerated() {
            lines.append("$\(slugs[index]): \(pair.hex);")
        }
        return lines.joined(separator: "\n")
    }

    private static func swiftUIString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.name })
        var lines = ["extension Color {"]
        for (index, pair) in pairs.enumerated() {
            let propName = camelCase(slugs[index])
            let comps = hexComponents(pair.hex)
            let r = String(format: "%.3f", Double(comps.r) / 255.0)
            let g = String(format: "%.3f", Double(comps.g) / 255.0)
            let b = String(format: "%.3f", Double(comps.b) / 255.0)
            lines.append("    static let \(propName) = Color(red: \(r), green: \(g), blue: \(b)) // \(pair.hex)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func tailwindString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.name })
        var lines = ["colors: {"]
        for (index, pair) in pairs.enumerated() {
            lines.append("  '\(slugs[index])': '\(pair.hex)',")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func jsonString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        if pairs.isEmpty { return "[]" }
        var lines = ["["]
        for (index, pair) in pairs.enumerated() {
            let comma = index == pairs.count - 1 ? "" : ","
            lines.append("  { \"name\": \"\(jsonEscape(pair.name))\", \"hex\": \"\(pair.hex)\" }\(comma)")
        }
        lines.append("]")
        return lines.joined(separator: "\n")
    }

    private static func plainHexString(_ palette: PaletteViewModel) -> String {
        palette.hexCodes.joined(separator: "\n")
    }

    private static func coolorsURLString(_ palette: PaletteViewModel) -> String {
        let hexes = palette.hexCodes.map { hex -> String in
            var cleaned = hex.lowercased()
            if cleaned.hasPrefix("#") { cleaned.removeFirst() }
            return cleaned
        }
        return "https://coolors.co/" + hexes.joined(separator: "-")
    }

    private static func svgString(_ palette: PaletteViewModel) -> String {
        let pairs = namesAndHexes(palette)
        let n = pairs.count
        let width = 100 * n
        if n == 0 {
            return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"0\" height=\"140\" viewBox=\"0 0 0 140\"></svg>"
        }
        var body = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(width)\" height=\"140\" viewBox=\"0 0 \(width) 140\">"
        for (i, pair) in pairs.enumerated() {
            let x = i * 100
            let textX = x + 50
            body += "<rect x=\"\(x)\" y=\"0\" width=\"100\" height=\"100\" fill=\"\(pair.hex)\"/>"
            body += "<text x=\"\(textX)\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system, sans-serif\" font-size=\"10\">\(xmlEscape(pair.name))</text>"
            body += "<text x=\"\(textX)\" y=\"132\" text-anchor=\"middle\" font-family=\"ui-monospace, monospace\" font-size=\"9\">\(pair.hex)</text>"
        }
        body += "</svg>"
        return body
    }
}
