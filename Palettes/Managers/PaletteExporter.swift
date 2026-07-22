//
//  PaletteExporter.swift
//  Palettes
//
//  Coolors-style palette export: code snippets, SVG, ASE, PDF, and share URL.
//

import Foundation
import UIKit

enum PaletteExportFormat: String, CaseIterable, Identifiable {
    case css, scss, swiftui, tailwind, json, plainHex, coolorsURL, svg, ase, pdf

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
        case .ase: return "ASE (Adobe Swatch)"
        case .pdf: return "PDF"
        }
    }

    /// True for binary formats that must be shared as a file rather than previewed as text.
    var isBinary: Bool {
        self == .ase || self == .pdf
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
        case .ase, .pdf: return ""
        }
    }

    // MARK: - Helpers

    /// Safely zips export rows with hexes; pads missing names with the hex sans `#`.
    ///
    /// `slugSource` is the color's role name when tagged (role slugs drive
    /// variable names in CSS/SCSS/Tailwind/SwiftUI, and the JSON `"role"`
    /// field), otherwise the color's own name. `displayName` is always the
    /// color's own name, regardless of role tagging — plain-hex, SVG,
    /// Coolors, ASE, and PDF formats always use this rather than the role
    /// (per plans/010 line 93 and this task's ASE/PDF review fix).
    private static func slugSourcesAndHexes(_ palette: PaletteViewModel) -> [(slugSource: String, hex: String, displayName: String, hasRole: Bool)] {
        let count = palette.hexCodes.count
        var result: [(String, String, String, Bool)] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let hex = palette.hexCodes[i]
            let name: String
            if i < palette.colorNames.count {
                name = palette.colorNames[i]
            } else {
                name = String(hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex))
            }
            let role = i < palette.paletteColors.count ? palette.paletteColors[i].role : nil
            let source = role ?? name
            result.append((source, hex, name, role != nil))
        }
        return result
    }

    /// Delegates to `ColorRole.slug` — the two used to be character-identical
    /// twins (this one doing the real export work, `ColorRole.slug` exercised
    /// only by tests). Keeping a single implementation means there's only one
    /// place left to fix if slugging rules ever change.
    private static func slugify(_ name: String) -> String {
        ColorRole(name: name).slug
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
        let pairs = slugSourcesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.slugSource })
        var lines = [":root {"]
        for (index, pair) in pairs.enumerated() {
            lines.append("  --\(slugs[index]): \(pair.hex);")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func scssString(_ palette: PaletteViewModel) -> String {
        let pairs = slugSourcesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.slugSource })
        var lines: [String] = []
        for (index, pair) in pairs.enumerated() {
            lines.append("$\(slugs[index]): \(pair.hex);")
        }
        return lines.joined(separator: "\n")
    }

    private static func swiftUIString(_ palette: PaletteViewModel) -> String {
        let pairs = slugSourcesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.slugSource })
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
        let pairs = slugSourcesAndHexes(palette)
        let slugs = uniqueSlugs(for: pairs.map { $0.slugSource })
        var lines = ["colors: {"]
        for (index, pair) in pairs.enumerated() {
            lines.append("  '\(slugs[index])': '\(pair.hex)',")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    private static func jsonString(_ palette: PaletteViewModel) -> String {
        let pairs = slugSourcesAndHexes(palette)
        if pairs.isEmpty { return "[]" }
        // Reuse the same dedup pass CSS/SCSS/Tailwind/SwiftUI use, so a
        // role's slug collides consistently everywhere (primary / primary-2).
        let slugs = uniqueSlugs(for: pairs.map { $0.slugSource })
        var lines = ["["]
        for (index, pair) in pairs.enumerated() {
            let comma = index == pairs.count - 1 ? "" : ","
            let roleField = pair.hasRole ? " \"role\": \"\(jsonEscape(slugs[index]))\"," : ""
            lines.append("  { \"name\": \"\(jsonEscape(pair.displayName))\",\(roleField) \"hex\": \"\(pair.hex)\" }\(comma)")
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
        let pairs = slugSourcesAndHexes(palette)
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
            body += "<text x=\"\(textX)\" y=\"118\" text-anchor=\"middle\" font-family=\"-apple-system, sans-serif\" font-size=\"10\">\(xmlEscape(pair.displayName))</text>"
            body += "<text x=\"\(textX)\" y=\"132\" text-anchor=\"middle\" font-family=\"ui-monospace, monospace\" font-size=\"9\">\(pair.hex)</text>"
        }
        body += "</svg>"
        return body
    }

    // MARK: - Phase 2: ASE

    /// Adobe Swatch Exchange binary encoding, big-endian.
    ///
    /// Layout: ASCII "ASEF"; UInt16 version major (1), UInt16 version minor (0);
    /// UInt32 block count. Per color: UInt16 blockType 0x0001; UInt32 blockLength
    /// (bytes after this field); UInt16 nameLength in UTF-16 code units including
    /// the null terminator; name as UTF-16BE bytes + 0x0000 terminator; 4 ASCII
    /// bytes "RGB " (trailing space); three big-endian Float32 (r,g,b in 0-1);
    /// UInt16 colorType 0x0002 (normal).
    static func aseData(_ palette: PaletteViewModel) -> Data {
        let pairs = slugSourcesAndHexes(palette)
        var data = Data()

        func appendUInt16(_ value: UInt16) {
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8(value & 0xFF))
        }
        func appendUInt32(_ value: UInt32) {
            data.append(UInt8((value >> 24) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8(value & 0xFF))
        }
        func appendFloat32BE(_ value: Float) {
            appendUInt32(value.bitPattern)
        }

        // Header
        data.append(contentsOf: Array("ASEF".utf8))
        appendUInt16(1) // version major
        appendUInt16(0) // version minor
        appendUInt32(UInt32(pairs.count)) // block count

        for pair in pairs {
            let nameUTF16: [UInt16] = Array(pair.displayName.utf16) + [0x0000]
            let nameLength = UInt16(nameUTF16.count)

            appendUInt16(0x0001) // block type: color entry
            let blockLength = UInt32(2 + Int(nameLength) * 2 + 4 + 12 + 2)
            appendUInt32(blockLength)
            appendUInt16(nameLength)
            for unit in nameUTF16 {
                appendUInt16(unit)
            }
            data.append(contentsOf: Array("RGB ".utf8)) // 4 ASCII bytes, trailing space
            let comps = hexComponents(pair.hex)
            appendFloat32BE(Float(comps.r) / 255.0)
            appendFloat32BE(Float(comps.g) / 255.0)
            appendFloat32BE(Float(comps.b) / 255.0)
            appendUInt16(0x0002) // color type: normal
        }

        return data
    }

    // MARK: - Phase 2: PDF

    @MainActor
    static func pdfData(_ palette: PaletteViewModel) -> Data {
        let pairs = slugSourcesAndHexes(palette)
        let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)

        return renderer.pdfData { context in
            context.beginPage()

            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let nameFont = UIFont.systemFont(ofSize: 14)
            let hexFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.black]
            let hexAttrs: [NSAttributedString.Key: Any] = [.font: hexFont, .foregroundColor: UIColor.darkGray]

            var y: CGFloat = 40
            let title = palette.name as NSString
            title.draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 50

            for pair in pairs {
                let comps = hexComponents(pair.hex)
                let uiColor = UIColor(
                    red: CGFloat(comps.r) / 255.0,
                    green: CGFloat(comps.g) / 255.0,
                    blue: CGFloat(comps.b) / 255.0,
                    alpha: 1.0
                )
                let swatchRect = CGRect(x: 40, y: y, width: 60, height: 40)
                uiColor.setFill()
                context.fill(swatchRect)

                let name = pair.displayName as NSString
                name.draw(at: CGPoint(x: 112, y: y), withAttributes: nameAttrs)

                let hex = pair.hex as NSString
                hex.draw(at: CGPoint(x: 112, y: y + 20), withAttributes: hexAttrs)

                y += 56
            }
        }
    }
}
