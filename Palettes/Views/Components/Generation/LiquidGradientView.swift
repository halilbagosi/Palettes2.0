//
//  LiquidGradientView.swift
//  Palettes
//

import SwiftUI

/// Animated, shader-driven flowing pastel gradient. Renders full-bleed in its frame.
struct LiquidGradientView: View {
    var speed: Double = 1
    var intensity: Double = 1
    /// When provided, the field flows through these colors instead of the generic pastels.
    var colors: [Color] = []

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                let time = timeline.date.timeIntervalSince(startDate) * speed
                if colors.isEmpty {
                    Rectangle()
                        .fill(.white)
                        .colorEffect(ShaderLibrary.liquidGradient(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(Float(time)),
                            .float(Float(intensity))
                        ))
                } else {
                    Rectangle()
                        .fill(.white.opacity(intensity))
                        .colorEffect(ShaderLibrary.orbFlow(
                            .float2(Float(geo.size.width), Float(geo.size.height)),
                            .float(Float(time)),
                            .float2(0.5, 0.5),
                            .float(0),
                            .colorArray(colors)
                        ))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LiquidGradientView()
        .ignoresSafeArea()
}
