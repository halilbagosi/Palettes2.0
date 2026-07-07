//
//  LiquidGradientView.swift
//  Palettes
//

import SwiftUI

/// Animated, shader-driven flowing pastel gradient. Renders full-bleed in its frame.
struct LiquidGradientView: View {
    var speed: Double = 1
    var intensity: Double = 1

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.liquidGradient(
                        .float2(Float(geo.size.width), Float(geo.size.height)),
                        .float(Float(timeline.date.timeIntervalSince(startDate) * speed)),
                        .float(Float(intensity))
                    ))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LiquidGradientView()
        .ignoresSafeArea()
}
