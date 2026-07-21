//
//  PaletteValidation.swift
//  Palettes
//
//  Pure post-generation validation rules: pairwise perceptual distinctness
//  and minimum brightness spread. No FoundationModels/iOS-26 gate — safe to
//  unit test directly.
//

import UIKit

enum PaletteValidation {
    static let minDeltaE: Double = 12
    static let minBrightnessSpan: Double = 0.35   // enforced for size >= 4

    /// Returns indices (excluding the locked prefix) that violate distinctness
    /// or brightness-spread rules. Locked colors (`index < lockedCount`) are
    /// never returned — when a locked color and a non-locked color are too
    /// similar, the non-locked one loses.
    static func violations(hexCodes: [String], lockedCount: Int) -> [Int] {
        let n = hexCodes.count
        guard n > 0 else { return [] }

        var bad = Set<Int>()

        // Pairwise perceptual distinctness: for every too-similar pair, the
        // later (higher-index) color loses, unless it's locked.
        for i in 0..<n {
            guard i + 1 < n else { break }
            for j in (i + 1)..<n {
                guard j >= lockedCount else { continue }
                let distance = ColorNamer.perceptualDistance(hex1: hexCodes[i], hex2: hexCodes[j])
                if distance < minDeltaE {
                    bad.insert(j)
                }
            }
        }

        // Minimum brightness spread — only meaningful once there are enough
        // colors to expect a light/dark range (size >= 4).
        if n >= 4, lockedCount < n {
            let brightnesses = hexCodes.map(brightness(ofHex:))
            let span = (brightnesses.max() ?? 0) - (brightnesses.min() ?? 0)
            if span < minBrightnessSpan {
                // Flag the non-locked color closest to the mean brightness —
                // the most redundant midtone — so a repair slot can bring in
                // a light or dark color and widen the spread.
                let mean = brightnesses.reduce(0, +) / Double(brightnesses.count)
                if let midtoneIndex = (lockedCount..<n).min(by: {
                    abs(brightnesses[$0] - mean) < abs(brightnesses[$1] - mean)
                }) {
                    bad.insert(midtoneIndex)
                }
            }
        }

        return bad.sorted()
    }

    // MARK: - Brightness

    private static func brightness(ofHex hex: String) -> Double {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h.removeAll { $0 == "#" }
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return 0.5 }
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        let ui = UIColor(red: r, green: g, blue: b, alpha: 1)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        ui.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        return Double(bri)
    }
}
