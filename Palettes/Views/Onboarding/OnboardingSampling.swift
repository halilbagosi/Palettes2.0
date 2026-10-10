//
//  OnboardingSampling.swift
//  Palettes
//
//  Pure geometry for sampling a color from the frozen frame inside the
//  circular orb. The orb draws the image `scaledToFill` in a square and fades
//  it out toward the rim, so a tap maps through the fill rect (the aspect-fit
//  `PhotoLoupeGeometry.imageRect` is the wrong shape here), then through
//  `PhotoLoupeGeometry.normalizedPoint`, exactly as `PhotoColorPickerView` does.
//

import CoreGraphics

enum OnboardingSampling {
    /// Where the sample lands before the user taps: the middle of the frame.
    static let center = CGPoint(x: 0.5, y: 0.5)

    /// The rect the image occupies when drawn `scaledToFill` and centered in
    /// a square of side `diameter` (it overflows on the longer axis).
    static func fillRect(imageSize: CGSize, diameter: CGFloat) -> CGRect {
        let square = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        guard imageSize.width > 0, imageSize.height > 0, diameter > 0 else { return square }
        let scale = max(diameter / imageSize.width, diameter / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        return CGRect(x: (diameter - w) / 2, y: (diameter - h) / 2, width: w, height: h)
    }

    /// Whether `point` (in the orb's local space) is inside the circle.
    static func isInsideOrb(_ point: CGPoint, diameter: CGFloat) -> Bool {
        let r = diameter / 2
        return hypot(point.x - r, point.y - r) <= r
    }

    /// The normalized image coordinate under a tap at `point` in the orb's
    /// local space, or nil when the tap is outside the circle.
    static func normalizedPoint(forTap point: CGPoint, imageSize: CGSize, diameter: CGFloat) -> CGPoint? {
        guard isInsideOrb(point, diameter: diameter) else { return nil }
        let rect = fillRect(imageSize: imageSize, diameter: diameter)
        return PhotoLoupeGeometry.normalizedPoint(in: rect, at: point)
    }

    /// Inverse of `normalizedPoint(forTap:)`: where a sampled point sits in
    /// the orb's local space, for drawing the marker. May fall outside the
    /// circle when the point is in the cropped part of the image.
    static func orbPoint(forNormalized point: CGPoint, imageSize: CGSize, diameter: CGFloat) -> CGPoint {
        let rect = fillRect(imageSize: imageSize, diameter: diameter)
        return CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}
