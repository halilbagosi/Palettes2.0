//
//  LinkSharer.swift
//  Palettes
//
//  Share for a palette or a color: the share sheet gets the SharedLink URL
//  with link metadata (title and an image of the colors), so Messages shows a
//  rich preview instead of a bare URL. The person who taps it lands in
//  Palettes (Save or Discard) or, without the app, on the App Store.
//

import LinkPresentation
import SwiftUI
import UIKit

@MainActor
enum LinkSharer {
    static func share(_ palette: PaletteViewModel) {
        let link = SharedLink.palette(name: palette.name, swatches: palette.paletteColors.map {
            SharedLink.Swatch(hex: $0.hex, name: $0.name, role: $0.role)
        })
        present(link, title: palette.name, image: thumbnail(hexes: palette.hexCodes))
    }

    static func share(_ color: ColorViewModel) {
        let link = SharedLink.color(name: color.name, hex: color.HEX)
        present(link, title: "\(color.name) \(color.HEX.uppercased())", image: thumbnail(hexes: [color.HEX]))
    }

    /// The link preview's picture: just the colors as bands, square, so the
    /// share sheet reads as a link, not as the PNG export (that's in Export…).
    private static func thumbnail(hexes: [String]) -> UIImage {
        let side: CGFloat = 300
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let colors = hexes.compactMap { hex -> UIColor? in
            guard let c = HexRGB.components(hex) else { return nil }
            return UIColor(red: CGFloat(c.r) / 255, green: CGFloat(c.g) / 255, blue: CGFloat(c.b) / 255, alpha: 1)
        }
        let bands = colors.isEmpty ? [UIColor.systemGray] : colors
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            let width = side / CGFloat(bands.count)
            for (index, color) in bands.enumerated() {
                color.setFill()
                // Overlap a point so no seam shows between bands.
                context.fill(CGRect(x: CGFloat(index) * width, y: 0, width: width + 1, height: side))
            }
        }
    }

    private static func present(_ link: SharedLink, title: String, image: UIImage?) {
        ShareSheetPresenter.present(items: [SharedLinkItem(url: link.url, title: title, image: image)])
    }
}

/// The URL plus its LPLinkMetadata. Copy and most apps get the URL; Mail
/// also gets the title as its subject.
private final class SharedLinkItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let image: UIImage?

    init(url: URL, title: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.image = image
    }

    nonisolated deinit {}

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let image {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}
