//
//  PhotoPinLocator.swift
//  Palettes
//
//  Where each color pulled from a photo sits in it, so From a Photo can put a
//  draggable pin on the spot. A coarse grid search is enough: the pin only
//  needs to start somewhere sensible; the user drags it from there.
//

import UIKit

enum PhotoPinLocator {
    /// Normalized (0…1, top-left origin) point whose pixel is closest to each hex.
    static func locate(hexes: [String], in sampler: ImageColorExtractor.PixelSampler, steps: Int = 48) -> [CGPoint] {
        let samples: [(point: CGPoint, rgb: (r: Double, g: Double, b: Double))] = (0..<steps).flatMap { yi in
            (0..<steps).map { xi in
                let p = CGPoint(x: (Double(xi) + 0.5) / Double(steps), y: (Double(yi) + 0.5) / Double(steps))
                return (p, sampler.color(at: p, radius: 1))
            }
        }
        return hexes.map { hex in
            guard let target = rgb(hex) else { return CGPoint(x: 0.5, y: 0.5) }
            return samples.min { distance($0.rgb, target) < distance($1.rgb, target) }?.point ?? CGPoint(x: 0.5, y: 0.5)
        }
    }

    private static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
    }

    private static func distance(_ a: (r: Double, g: Double, b: Double), _ b: (r: Double, g: Double, b: Double)) -> Double {
        let dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b
        return dr * dr + dg * dg + db * db
    }
}
