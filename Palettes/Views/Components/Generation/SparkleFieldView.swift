//
//  SparkleFieldView.swift
//  Palettes
//

import SwiftUI

/// A field of tiny twinkling sparkles that drift slowly upward.
/// Stateless: every sparkle's position, hue, size and rhythm derive from its index.
struct SparkleFieldView: View {
    var count: Int = 28
    var tints: [Color] = [.yellow, .orange, .pink, .purple, .indigo, .blue, .cyan]

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(startDate)

                for i in 0..<count {
                    let fi = Double(i)
                    let seed = fi * 127.1

                    let x = (sin(seed * 3.7) * 0.5 + 0.5) * size.width
                    let baseY = (sin(seed * 7.3) * 0.5 + 0.5) * size.height

                    let driftSpeed = 6 + fi.truncatingRemainder(dividingBy: 5) * 3
                    var y = (baseY - t * driftSpeed).truncatingRemainder(dividingBy: size.height + 40)
                    if y < -20 { y += size.height + 40 }

                    let twinkle = 0.5 + 0.5 * sin(t * (1.2 + fi.truncatingRemainder(dividingBy: 3)) + seed)
                    let side = (3 + 5 * (sin(seed * 13.7) * 0.5 + 0.5)) * (0.7 + 0.6 * twinkle)

                    var glyph = context.resolve(Image(systemName: "sparkle"))
                    glyph.shading = .color(tints[i % tints.count].opacity(0.2 + 0.55 * twinkle))

                    context.draw(glyph, in: CGRect(x: x, y: y, width: side, height: side))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    SparkleFieldView()
        .background(Color(.systemBackground))
        .ignoresSafeArea()
}
