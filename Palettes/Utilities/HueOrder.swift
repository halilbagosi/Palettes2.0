//
//  HueOrder.swift
//  Palettes
//
//  The "Hue" library sort: colors around the color wheel (red, orange,
//  yellow … violet, pink), with grays, blacks and whites after them, light to
//  dark. A palette sorts by the average hue of its colors, the more vivid
//  ones counting for more.
//

import Foundation

nonisolated enum HueOrder {
    /// Below this saturation (HSB) a color reads as a gray and sorts with the neutrals.
    static let neutralSaturation = 0.12
    /// Below this brightness a color reads as black, whatever its saturation.
    static let neutralBrightness = 0.12

    /// Where a color or palette goes in hue order; compare with `<`.
    struct Key: Comparable {
        /// Chromatic colors (false) come before neutrals (true).
        var isNeutral: Bool
        /// 0..<1 around the wheel; 0 for neutrals.
        var hue: Double
        /// Neutrals, and equal hues, go light to dark.
        var brightness: Double

        static func < (a: Key, b: Key) -> Bool {
            if a.isNeutral != b.isNeutral { return !a.isNeutral }
            if a.hue != b.hue { return a.hue < b.hue }
            return a.brightness > b.brightness
        }
    }

    /// Key for one "#RRGGBB" (or "RRGGBB") hex; an unreadable hex sorts last.
    static func key(forHex hex: String) -> Key {
        guard let (h, s, b) = hsb(hex) else { return Key(isNeutral: true, hue: 0, brightness: -1) }
        if s < neutralSaturation || b < neutralBrightness {
            return Key(isNeutral: true, hue: 0, brightness: b)
        }
        return Key(isNeutral: false, hue: h, brightness: b)
    }

    /// Key for a palette: the circular mean of its chromatic colors' hues,
    /// weighted by saturation. A palette of only neutrals sorts with the
    /// neutrals by its mean brightness.
    static func key(forHexes hexes: [String]) -> Key {
        let colors = hexes.compactMap(hsb)
        guard !colors.isEmpty else { return Key(isNeutral: true, hue: 0, brightness: -1) }
        var x = 0.0, y = 0.0, weight = 0.0
        for (h, s, b) in colors where s >= neutralSaturation && b >= neutralBrightness {
            x += cos(h * 2 * .pi) * s
            y += sin(h * 2 * .pi) * s
            weight += s
        }
        let brightness = colors.map(\.b).reduce(0, +) / Double(colors.count)
        guard weight > 0, hypot(x, y) > 1e-9 else {
            return Key(isNeutral: true, hue: 0, brightness: brightness)
        }
        var hue = atan2(y, x) / (2 * .pi)
        if hue < 0 { hue += 1 }
        return Key(isNeutral: false, hue: hue, brightness: brightness)
    }

    /// HSB (each 0...1) of a 6-digit hex.
    static func hsb(_ hex: String) -> (h: Double, s: Double, b: Double)? {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        let s = maxC == 0 ? 0 : delta / maxC
        var h = 0.0
        if delta > 0 {
            switch maxC {
            case r: h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g: h = (b - r) / delta + 2
            default: h = (r - g) / delta + 4
            }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, s, maxC)
    }
}
