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

/// Pinch-to-zoom state for a photo shown aspect-fit: how far it is magnified
/// and how far its center has been panned from where it rests.
nonisolated struct PhotoZoom: Equatable {
    static let maxScale: CGFloat = 8

    var scale: CGFloat = 1
    var offset: CGSize = .zero

    /// Where the photo is drawn, given its unzoomed rect.
    func rect(for base: CGRect) -> CGRect {
        let size = CGSize(width: base.width * scale, height: base.height * scale)
        return CGRect(x: base.midX + offset.width - size.width / 2,
                      y: base.midY + offset.height - size.height / 2,
                      width: size.width, height: size.height)
    }

    /// Applies one step of a pinch: the fingers' midpoint moved from `previous`
    /// to `current` while they spread by `factor`. The spot of the photo under
    /// the midpoint stays under it, then the photo is kept from leaving
    /// `window` (it covers the window on any axis it's larger than, and stays
    /// centered on any axis it isn't).
    mutating func pinch(by factor: CGFloat, from previous: CGPoint, to current: CGPoint,
                        base: CGRect, window: CGRect) {
        guard factor.isFinite, factor > 0, base.width > 0, base.height > 0 else { return }
        let newScale = min(max(scale * factor, 1), Self.maxScale)
        let applied = newScale / scale
        let center = CGPoint(x: base.midX + offset.width, y: base.midY + offset.height)
        let moved = CGPoint(x: current.x + (center.x - previous.x) * applied,
                            y: current.y + (center.y - previous.y) * applied)
        scale = newScale
        let slackX = max(0, (base.width * newScale - window.width) / 2)
        let slackY = max(0, (base.height * newScale - window.height) / 2)
        let x = min(max(moved.x, window.midX - slackX), window.midX + slackX)
        let y = min(max(moved.y, window.midY - slackY), window.midY + slackY)
        // At rest the photo sits at `base`, wherever that is in the window.
        offset = newScale == 1 ? .zero : CGSize(width: x - base.midX, height: y - base.midY)
    }
}
