//
//  SwatchStrip.swift
//  PalettesWidgets
//
//  Colours drawn as an image, not as shapes: in tinted and clear Home
//  Screen modes the system recolours shapes, but an image marked
//  full-colour keeps its colours. One pixel per colour, stretched without
//  smoothing, gives crisp equal bands at any size.
//

import SwiftUI
import UIKit
import WidgetKit

struct SwatchStrip: View {
    let hexes: [String]

    var body: some View {
        Image(uiImage: Self.image(for: hexes))
            .resizable()
            .interpolation(.none)
            .fullColorInAccentedModes()
            .accessibilityHidden(true)
    }

    static func image(for hexes: [String]) -> UIImage {
        let list = hexes.isEmpty ? [HexRGB.fallbackGrey] : hexes
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard
        let size = CGSize(width: list.count, height: 1)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            for (index, hex) in list.enumerated() {
                let c = HexRGB.components(hex) ?? HexRGB.components(HexRGB.fallbackGrey)!
                UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1).setFill()
                context.fill(CGRect(x: index, y: 0, width: 1, height: 1))
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
