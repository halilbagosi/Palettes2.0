//
//  HexRGB.swift
//  Palettes (app + widgets)
//
//  Hex parsing shared by the app and the widget extension. `Color(hex:)`
//  delegates here, so both read hex exactly the same way.
//

import Foundation

nonisolated enum HexRGB {
    /// Drawn wherever a stored hex can't be parsed.
    static let fallbackGrey = "#8E8E93"

    /// 0...255 components, or nil for anything that isn't 3, 4, 6 or 8 hex
    /// digits (optional leading "#"). Alpha digits are discarded.
    static func components(_ hex: String) -> (r: Int, g: Int, b: Int)? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        switch cleaned.count {
        case 3, 4:
            cleaned = cleaned.map { "\($0)\($0)" }.joined()
        case 6, 8:
            break
        default:
            return nil
        }

        // `UInt64(_:radix:)` also accepts a leading "+" or "-", so check the
        // digits first; `isHexDigit` alone would let fullwidth digits through.
        guard cleaned.allSatisfy(\.isHexDigit), let number = UInt64(cleaned, radix: 16) else {
            return nil
        }

        // For 8-digit (RRGGBBAA) input, shift past the discarded alpha byte.
        let shifted = number >> (cleaned.count == 8 ? 8 : 0)
        return (Int((shifted >> 16) & 0xFF), Int((shifted >> 8) & 0xFF), Int(shifted & 0xFF))
    }

    /// WCAG relative luminance: 0 for black, 1 for white.
    static func luminance(_ hex: String) -> Double? {
        guard let c = components(hex) else { return nil }
        func linear(_ v: Int) -> Double {
            let s = Double(v) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    /// True when dark text contrasts better than white on this colour
    /// (luminance above 0.179, where the two contrast ratios cross).
    /// Malformed hex is judged as `fallbackGrey`, which is what gets drawn.
    static func isLight(_ hex: String) -> Bool {
        (luminance(hex) ?? luminance(fallbackGrey) ?? 0) > 0.179
    }
}
