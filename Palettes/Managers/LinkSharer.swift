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
        present(link, title: palette.name, image: PaletteImageRenderer.renderImage(for: palette))
    }

    static func share(_ color: ColorViewModel) {
        let link = SharedLink.color(name: color.name, hex: color.HEX)
        present(link, title: "\(color.name) \(color.HEX.uppercased())", image: PaletteImageRenderer.renderImage(for: color))
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
