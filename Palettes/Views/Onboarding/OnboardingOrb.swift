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
    var colors: [Color] = []

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .orbGlass(in: .circle)

            GenerationOrbView(colors: colors)

            Circle()
                .fill(.black)
                .opacity(blackFill)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Color orb")
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingOrb(diameter: 220, blackFill: 1)
        OnboardingOrb(diameter: 220, blackFill: 0)
    }
    .padding()
    .background(Color(.systemBackground))
}
