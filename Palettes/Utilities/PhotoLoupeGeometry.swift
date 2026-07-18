import CoreGraphics

/// Pure geometry for mapping a touch point inside an aspect-fit image view
/// onto a normalized (0–1) image coordinate. Isolated from SwiftUI so the
/// letterbox math is unit-testable.
enum PhotoLoupeGeometry {

    /// Maps a point in view space to a normalized image point, assuming the
    /// image is displayed aspect-fit (letterboxed) inside `viewSize`.
    /// Touches over letterbox bars clamp to `[0,1]`.
    static func normalizedPoint(
        forViewPoint viewPoint: CGPoint,
        viewSize: CGSize,
        imageSize: CGSize
    ) -> CGPoint {
        guard viewSize.width > 0, viewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height

        let displayW: CGFloat
        let displayH: CGFloat
        if imageAspect > viewAspect {
            // Image fills the view width; bars top and bottom.
            displayW = viewSize.width
            displayH = viewSize.width / imageAspect
        } else {
            // Image fills the view height; bars left and right.
            displayH = viewSize.height
            displayW = viewSize.height * imageAspect
        }
        let originX = (viewSize.width - displayW) / 2
        let originY = (viewSize.height - displayH) / 2

        let nx = (viewPoint.x - originX) / displayW
        let ny = (viewPoint.y - originY) / displayH
        return CGPoint(x: clamp01(nx), y: clamp01(ny))
    }

    private static func clamp01(_ v: CGFloat) -> CGFloat {
        min(1, max(0, v))
    }
}
