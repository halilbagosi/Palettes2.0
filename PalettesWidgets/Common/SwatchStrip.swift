//
//  SwatchStrip.swift
//  PalettesWidgets
//
//  Colours drawn as an image, not as shapes: in tinted and clear Home
//  Screen modes the system recolours shapes, but an image marked
//  full-colour keeps its colours. Drawn at the exact pixel size it is shown
//  at, with band edges on whole pixels, so bands are crisp at any size.
//

import SwiftUI
import UIKit
import WidgetKit

struct SwatchStrip: View {
    let hexes: [String]
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: Self.image(for: hexes, size: proxy.size, scale: displayScale))
                .resizable()
                .interpolation(.none)
                .fullColorInAccentedModes()
        }
        .accessibilityHidden(true)
    }

    /// Pixel columns where each band starts, plus the final edge (count + 1
    /// values, first 0, last `pixelWidth`). Edges are rounded to whole pixels
    /// so bands differ by at most one pixel and never straddle a pixel.
    static func bandEdges(count: Int, pixelWidth: Int) -> [Int] {
        let n = max(count, 1)
        return (0...n).map { i in
            Int((Double(pixelWidth) * Double(i) / Double(n)).rounded())
        }
    }

    /// The strip as a `pixelWidth` x 1 image, where `pixelWidth` is the point
    /// width times the display scale. Only the width needs pixel precision
    /// (bands are vertical), and the single row stretches vertically without
    /// smoothing, so the image stays tiny. Stretching a one-pixel-per-colour
    /// image to a fractional width instead snaps band edges unevenly and
    /// leaves stair-steps under the rounded clip.
    static func image(for hexes: [String], size: CGSize, scale: CGFloat) -> UIImage {
        let list = hexes.isEmpty ? [HexRGB.fallbackGrey] : hexes
        let pixelWidth = max(Int((size.width * max(scale, 1)).rounded()), 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let edges = bandEdges(count: list.count, pixelWidth: pixelWidth)
        return UIGraphicsImageRenderer(size: CGSize(width: pixelWidth, height: 1), format: format).image { context in
            let cg = context.cgContext
            cg.interpolationQuality = .none
            cg.setShouldAntialias(false)
            for (index, hex) in list.enumerated() {
                let c = HexRGB.components(hex) ?? HexRGB.components(HexRGB.fallbackGrey)!
                UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1).setFill()
                cg.fill(CGRect(x: edges[index], y: 0, width: edges[index + 1] - edges[index], height: 1))
            }
        }
    }
}

extension Image {
    @ViewBuilder
    func fullColorInAccentedModes() -> some View {
        if #available(iOS 18.0, *) {
            widgetAccentedRenderingMode(.fullColor)
        } else {
            self
        }
    }
}
