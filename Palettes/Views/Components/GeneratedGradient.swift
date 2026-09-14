import Foundation
import SwiftUI

/// The animated spectrum used by Apple Intelligence-generated content.
///
/// Keeping the palette and mesh motion here means generated badges and the
/// generation form's glyph always share the same visual language.
@available(iOS 26.0, *)
enum GeneratedGradient {
    // A slightly shorter half-cycle keeps the movement lively without becoming
    // hectic.
    static let cycleDuration: TimeInterval = 3

    static func phase(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSinceReferenceDate
        let fullCycle = cycleDuration * 2
        let cycle = (elapsed.truncatingRemainder(dividingBy: fullCycle) + fullCycle)
            .truncatingRemainder(dividingBy: fullCycle)
        let progress = cycle <= cycleDuration
            ? cycle / cycleDuration
            : 2 - cycle / cycleDuration

        // Ease into each endpoint so the gradient reverses without a visible
        // snap when it changes direction.
        return CGFloat(0.5 - 0.5 * cos(progress * .pi))
    }

    static func style(phase: CGFloat) -> AnyShapeStyle {
        let t = Float(phase)
        // Keep the mesh drift subtle so the faster color movement still reads
        // as one continuous, fluid surface.
        let d: Float = 0.15
        let angle = t * .pi * 2
        let secondaryAngle = angle * 1.7

        return AnyShapeStyle(MeshGradient(
            width: 3,
            height: 3,
            points: [
                SIMD2(-0.5, -0.5),
                SIMD2(0.5 + d * sin(angle + 0.35), -0.5),
                SIMD2(1.5, -0.5),
                SIMD2(-0.5, 0.5 + d * cos(secondaryAngle + 1.1)),
                SIMD2(
                    0.5 + d * cos(angle * 1.15),
                    0.5 + d * sin(secondaryAngle + 1.4)
                ),
                SIMD2(1.5, 0.5 - d * cos(angle * 0.85 + 2.2)),
                SIMD2(-0.5, 1.5),
                SIMD2(0.5 - d * sin(secondaryAngle + 1.8), 1.5),
                SIMD2(1.5, 1.5)
            ],
            colors: colors(for: phase)
        ))
    }

    private static func colors(for phase: CGFloat) -> [Color] {
        let normalizedPhase = Double(phase)
        let angle = normalizedPhase * .pi * 2
        let palettes = (paletteA, paletteB)

        // Add small, per-stop waves to make the color travel feel organic
        // while keeping every transition continuous at the cycle endpoints.
        return palettes.0.indices.map { index in
            let offset = Double(index) * 0.73
            let variation = (
                0.12 * sin(angle * 2 + offset)
                + 0.05 * cos(angle * 3 - offset * 0.4)
            ) * sin(.pi * normalizedPhase)
            let blend = min(max(normalizedPhase + variation, 0), 1)

            let first = palettes.0[index]
            let second = palettes.1[index]
            return Color(
                red: first.red + (second.red - first.red) * blend,
                green: first.green + (second.green - first.green) * blend,
                blue: first.blue + (second.blue - first.blue) * blend
            )
        }
    }

    // Reference spectrum: warm orange and coral across the top, then pink,
    // cyan, and lavender as the color travels toward the bottom.
    private static let paletteA: [(red: Double, green: Double, blue: Double)] = [
        (0.99, 0.68, 0.15), (0.98, 0.47, 0.31), (1.00, 0.21, 0.41),
        (0.93, 0.75, 0.55), (0.80, 0.60, 0.67), (0.98, 0.42, 0.78),
        (0.64, 0.83, 0.91), (0.22, 0.74, 1.00), (0.83, 0.63, 1.00)
    ]

    private static let paletteB: [(red: Double, green: Double, blue: Double)] = [
        (1.00, 0.59, 0.08), (1.00, 0.32, 0.32), (1.00, 0.06, 0.35),
        (0.84, 0.64, 0.42), (0.78, 0.42, 0.68), (0.96, 0.20, 0.68),
        (0.40, 0.72, 0.88), (0.06, 0.66, 0.96), (0.70, 0.40, 1.00)
    ]
}

@available(iOS 26.0, *)
struct GeneratedBadge: View {
    let isCompact: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: isCompact ? 0 : 6) {
                Image(systemName: "apple.intelligence")
                    .font(.subheadline.weight(.semibold))

                if !isCompact {
                    Text("Generated")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(GeneratedGradient.style(phase: GeneratedGradient.phase(at: timeline.date)))
            .padding(.horizontal, isCompact ? 9 : 10)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .liquidGlass(.regular, in: .capsule)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apple Intelligence Generated")
        .allowsHitTesting(false)
    }
}
