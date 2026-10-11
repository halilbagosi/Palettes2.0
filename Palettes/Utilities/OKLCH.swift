//
//  OKLCH.swift
//  Palettes
//
//  OKLCH (Björn Ottosson's OKLab in polar form). Equal steps of lightness
//  and hue in OKLCH look equal to the eye, which HSB steps do not: an HSB
//  brightness ladder turns muddy in blues and garish in yellows. The palette
//  builder works in this space. Pure math — safe to unit test.
//

import Foundation

struct OKLCH: Equatable {
    /// Perceptual lightness, 0 (black) ... 1 (white).
    var L: Double
    /// Chroma, 0 (grey) ... about 0.32 for the most saturated sRGB colors.
    var C: Double
    /// Hue angle in degrees, 0 ..< 360.
    var h: Double

    init(L: Double, C: Double, h: Double) {
        self.L = min(1, max(0, L))
        self.C = max(0, C)
        self.h = OKLCH.wrap(h)
    }

    // MARK: - Hue helpers

    static func wrap(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    /// Shortest angle between two hues, 0 ... 180.
    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(wrap(a) - wrap(b))
        return min(d, 360 - d)
    }

    // MARK: - sRGB → OKLCH

    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    /// Gamma-encoded sRGB components, each 0...1.
    init(r: Double, g: Double, b: Double) {
        let lr = OKLCH.linearize(r), lg = OKLCH.linearize(g), lb = OKLCH.linearize(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        let okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        let chroma = (okA * okA + okB * okB).squareRoot()
        // Hue is meaningless for a grey; 0 keeps it deterministic.
        let hue = chroma < 1e-6 ? 0 : atan2(okB, okA) * 180 / .pi
        self.init(L: okL, C: chroma, h: hue)
    }

    // MARK: - OKLCH → sRGB

    /// Linear-light sRGB, unclamped. A component outside 0...1 means the
    /// color is outside the sRGB gamut.
    func linearSRGB() -> (r: Double, g: Double, b: Double) {
        let radians = h * .pi / 180
        let a = C * cos(radians)
        let b = C * sin(radians)
        let l = OKLCH.cube(L + 0.3963377774 * a + 0.2158037573 * b)
        let m = OKLCH.cube(L - 0.1055613458 * a - 0.0638541728 * b)
        let s = OKLCH.cube(L - 0.0894841775 * a - 1.2914855480 * b)
        return (
            4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        )
    }

    var isInSRGBGamut: Bool {
        let c = linearSRGB()
        let range = -0.0001...1.0001
        return range.contains(c.r) && range.contains(c.g) && range.contains(c.b)
    }

    /// The same lightness and hue with chroma reduced just enough to fit in
    /// sRGB. Holding L and h fixed keeps a clipped color on its hue and its
    /// place in the lightness ladder; RGB clamping would shift both.
    func gamutMapped() -> OKLCH {
        if isInSRGBGamut { return self }
        var low = 0.0
        var high = C
        for _ in 0..<24 {
            let mid = (low + high) / 2
            if OKLCH(L: L, C: mid, h: h).isInSRGBGamut { low = mid } else { high = mid }
        }
        return OKLCH(L: L, C: low, h: h)
    }

    /// "#RRGGBB" of the gamut-mapped color.
    var hex: String {
        let c = gamutMapped().linearSRGB()
        func byte(_ linear: Double) -> Int {
            Int((OKLCH.gammaEncode(min(1, max(0, linear))) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", byte(c.r), byte(c.g), byte(c.b))
    }

    // MARK: - Transfer functions

    private static func linearize(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private static func gammaEncode(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    private static func cube(_ x: Double) -> Double { x * x * x }
}
