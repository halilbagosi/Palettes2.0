import CoreGraphics

/// Pure geometry for an aspect-fit image inside a view. Isolated from SwiftUI so
/// the letterbox math is unit-testable.
enum PhotoLoupeGeometry {

    /// The on-screen rect an image occupies when displayed aspect-fit (centered,
    /// letterboxed) inside `viewSize`. Callers use this both to draw a marker at
    /// the sampled point and to clamp touches to the image (excluding bars).
    static func imageRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let w: CGFloat
        let h: CGFloat
        if imageAspect > viewAspect {
            // Image fills the view width; bars top and bottom.
            w = viewSize.width
            h = viewSize.width / imageAspect
        } else {
            // Image fills the view height; bars left and right.
            h = viewSize.height
            w = viewSize.height * imageAspect
        }
        return CGRect(x: (viewSize.width - w) / 2,
                      y: (viewSize.height - h) / 2,
                      width: w, height: h)
    }

    /// Normalized (0–1) image coordinate for a point already clamped to
    /// `imageRect`. `(0,0)` = top-left of the image, `(1,1)` = bottom-right.
    static func normalizedPoint(in imageRect: CGRect, at point: CGPoint) -> CGPoint {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        return CGPoint(
            x: clamp01((point.x - imageRect.minX) / imageRect.width),
            y: clamp01((point.y - imageRect.minY) / imageRect.height)
        )
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat {
        min(1, max(0, v))
    }
}
