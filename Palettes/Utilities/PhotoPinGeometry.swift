//
//  PhotoPinGeometry.swift
//  Palettes
//
//  Pure geometry for a point picked on a photo, kept apart from SwiftUI so it
//  can be tested. Points are normalized image coordinates (0…1, top-left
//  origin).
//

import CoreGraphics

enum PhotoPinGeometry {
    /// Where a pin that started at `origin` ends up after the finger moved by
    /// `translation` (view points), clamped to the image rect.
    static func moved(from origin: CGPoint, by translation: CGSize, in rect: CGRect) -> CGPoint {
        let start = position(of: origin, in: rect)
        let target = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        let clamped = CGPoint(
            x: min(max(target.x, rect.minX), rect.maxX),
            y: min(max(target.y, rect.minY), rect.maxY)
        )
        return PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
    }

    /// 5% of the image width per VoiceOver step, left (-1) or right (+1).
    static func nudged(_ point: CGPoint, by direction: Int) -> CGPoint {
        CGPoint(x: min(max(point.x + 0.05 * Double(direction), 0), 1), y: point.y)
    }

    /// The view position of a normalized point.
    static func position(of point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}
