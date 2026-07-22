//
//  RoleBadge.swift
//  Palettes
//
//  Small capsule shown on a palette swatch row when the color has been
//  tagged with a role (built-in like "Primary", or a custom tag). Uses the
//  existing `liquidGlass` compatibility shim so it gets real Liquid Glass on
//  iOS 26+ and an `.ultraThinMaterial` capsule fallback on iOS 17–25.
//

import SwiftUI

struct RoleBadge: View {
    let role: String

    /// Concentricity rule: a shape nested inside another shares its center
    /// of curvature only when its radius equals the outer radius minus the
    /// inset between them. This badge sits `ColorCellBig.overlayInset` in
    /// from the card's edge, so its radius is the card's corner radius minus
    /// that inset (28 − 12 = 16). Do NOT simplify this back to `.capsule` —
    /// a capsule's corners don't nest inside the card's `.continuous` 28pt
    /// corners, which is exactly the mismatch this shape fixes. If
    /// `ColorCellBig.cornerRadius`/`overlayInset` ever change, this stays
    /// correct because it's derived, not hardcoded.
    private static var cornerRadius: CGFloat {
        ColorCellBig.cornerRadius - ColorCellBig.overlayInset
    }

    var body: some View {
        Text(role)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.6)
        VStack {
            RoleBadge(role: "Primary")
            RoleBadge(role: "Marketing")
        }
    }
    .frame(width: 240, height: 160)
}
