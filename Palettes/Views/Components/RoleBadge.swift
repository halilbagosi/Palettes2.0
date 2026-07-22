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

    var body: some View {
        Text(role)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .liquidGlass(.regular, in: .capsule)
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
