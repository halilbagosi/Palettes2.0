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
            // Stops sit on the bounds (not outside them) so every color —
            // including the corners — shows up on small glyphs.
            points: [
                SIMD2(0, 0),
                SIMD2(0.5 + d * sin(angle + 0.35), 0),
                SIMD2(1, 0),
                SIMD2(0, 0.5 + d * cos(secondaryAngle + 1.1)),
                SIMD2(
                    0.5 + d * cos(angle * 1.15),
                    0.5 + d * sin(secondaryAngle + 1.4)
                ),
                SIMD2(1, 0.5 - d * cos(angle * 0.85 + 2.2)),
                SIMD2(0, 1),
                SIMD2(0.5 - d * sin(secondaryAngle + 1.8), 1),
                SIMD2(1, 1)
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

    // Reference spectrum: sampled from the lower half of the iOS 27 Siri
    // icon — muted, metallic tints running diagonally from dusty rose in the
    // top-leading corner through warm sand and pale butter to misty cyan and
    // steel blue in the bottom-trailing corner. Palette B is a slightly
    // lighter pass of the same hues so the animation reads as a sheen rather
    // than a hue shift.
    private static let paletteA: [(red: Double, green: Double, blue: Double)] = [
        (0.61, 0.53, 0.49), (0.70, 0.64, 0.54), (0.69, 0.69, 0.57),
        (0.70, 0.64, 0.54), (0.69, 0.69, 0.57), (0.54, 0.65, 0.70),
        (0.69, 0.69, 0.57), (0.54, 0.65, 0.70), (0.42, 0.53, 0.64)
    ]

    private static let paletteB: [(red: Double, green: Double, blue: Double)] = [
        (0.70, 0.61, 0.57), (0.79, 0.73, 0.62), (0.78, 0.78, 0.65),
        (0.79, 0.73, 0.62), (0.78, 0.78, 0.65), (0.62, 0.74, 0.79),
        (0.78, 0.78, 0.65), (0.62, 0.74, 0.79), (0.50, 0.62, 0.73)
    ]
}

@available(iOS 26.0, *)
struct GeneratedBadge: View {
    /// Match the card's copy button so the two read as one column.
    var diameter: CGFloat = 40

    var body: some View {
        TimelineView(.animation) { timeline in
            Image(systemName: "apple.intelligence")
                .font(.body.weight(.semibold))
                .frame(width: diameter, height: diameter)
                .foregroundStyle(GeneratedGradient.style(phase: GeneratedGradient.phase(at: timeline.date)))
        }
        // The muted spectrum washes out on saturated cards; a dark disc
        // keeps it legible everywhere.
        .background(Circle().fill(.black.opacity(0.55)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apple Intelligence Generated")
        .allowsHitTesting(false)
    }
}
