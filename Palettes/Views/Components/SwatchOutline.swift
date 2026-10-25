//
//  SwatchOutline.swift
//  Palettes
//

import SwiftUI

extension View {
    /// The hairline outline the color detail swatch uses, shared by cards and
    /// color circles so colors close to the background (near-white in light
    /// mode, near-black in dark mode) still read as a separate shape.
    /// Apply it after any `clipShape` so the stroke isn't clipped.
    func swatchOutline<S: Shape>(_ shape: S) -> some View {
        overlay(shape.stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}
