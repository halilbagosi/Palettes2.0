//
//  OnboardingOrb.swift
//  Palettes
//
//  The onboarding orb: starts as a black blob at the Dynamic Island, then
//  detaches and clears into the app's liquid glass orb.
//

import SwiftUI

struct OnboardingOrb: View {
    var diameter: CGFloat
    /// 1 = solid black (island), 0 = fully clear glass.
    var blackFill: Double
    var label: String
    var colors: [Color] = []
    var backdrop: AnyView? = nil
    var backdropID: Int = 0

    var body: some View {
        ZStack {
            // Draws its own glass shell (material fallback before iOS 26).
            GenerationOrbView(colors: colors, interactive: false, backdrop: backdrop, backdropID: backdropID)

            Circle()
                .fill(.black)
                .opacity(blackFill)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingOrb(diameter: 220, blackFill: 1, label: "Orb")
        OnboardingOrb(diameter: 220, blackFill: 0, label: "Orb")
    }
    .padding()
    .background(Color(.systemBackground))
}
