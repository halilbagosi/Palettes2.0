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
    /// 5% of the image width per VoiceOver step, left (-1) or right (+1).
    static func nudged(_ point: CGPoint, by direction: Int) -> CGPoint {
        CGPoint(x: min(max(point.x + 0.05 * Double(direction), 0), 1), y: point.y)
    }

    /// The view position of a normalized point.
    static func position(of point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}
