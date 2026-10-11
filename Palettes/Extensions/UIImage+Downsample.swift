//
//  UIImage+Downsample.swift
//  Palettes
//

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
}
