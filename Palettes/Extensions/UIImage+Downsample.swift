//
//  UIImage+Downsample.swift
//  Palettes
//

import ImageIO
import UIKit

extension UIImage {
    /// A phone photo is far bigger than anything shown or sampled here; one
    /// small copy serves display, sampling and extraction. Returns `self`
    /// when the long side is already within `longSide`; otherwise a scale-1
    /// copy whose long side is `longSide`, aspect kept.
    func downsampled(longSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > longSide else { return self }
        let scale = longSide / longest
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Decodes image data straight to a thumbnail whose long side is at most
    /// `longSide`, upright (EXIF orientation applied), without ever holding the
    /// full-size bitmap. Smaller images are decoded at their own size. Safe to
    /// call off the main actor.
    nonisolated static func downsampled(from data: Data, longSide: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        // The max-size key can enlarge small images; only set it when shrinking.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        if max(width, height) > longSide || width == 0 {
            options[kCGImageSourceThumbnailMaxPixelSize] = longSide
        }
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
