//
//  GenerationOrbView.swift
//  Palettes
//

import SwiftUI

/// Full-screen Siri-style waiting stage: liquid glass orb with a rotating
/// iridescent rim over a soft shader gradient.
struct GenerationOrbView: View {
    let statusText: String

    @State private var breathe = false
    private let startDate = Date()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea()

            LiquidGradientView(speed: 0.6, intensity: 0.45)
                .blur(radius: 70)
                .ignoresSafeArea()

            orb
        }
    }

    // MARK: - Orb

    private var orb: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)

            ZStack {
                // Soft halo lifting the orb off the gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(.systemBackground).opacity(0.9), .clear],
                            center: .center, startRadius: 60, endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)

                chromaticRim(rotation: t * 40)

                // Glass body
                Circle()
                    .fill(Color(.systemBackground).opacity(0.55))
                    .frame(width: 320, height: 320)
                    .glassEffect(.regular, in: .circle)

                VStack(spacing: 28) {
                    Text(statusText)
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 44)

                    shimmerBar(time: t)
                }
                .frame(width: 320)
            }
            .scaleEffect(breathe ? 1.04 : 0.98)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: - Chromatic Rim

    private func chromaticRim(rotation: Double) -> some View {
        let rainbow: [Color] = [.cyan, .blue, .purple, .pink, .orange, .yellow, .cyan]
        return Circle()
            .strokeBorder(
                AngularGradient(colors: rainbow, center: .center),
                lineWidth: 10
            )
            .frame(width: 324, height: 324)
            .blur(radius: 9)
            .mask {
                ZStack {
                    Circle()
                        .trim(from: 0.02, to: 0.30)
                        .stroke(style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    Circle()
                        .trim(from: 0.52, to: 0.74)
                        .stroke(style: StrokeStyle(lineWidth: 22, lineCap: .round))
                }
                .frame(width: 324, height: 324)
            }
            .rotationEffect(.degrees(rotation))
    }

    // MARK: - Shimmer

    private func shimmerBar(time: Double) -> some View {
        let phase = time.truncatingRemainder(dividingBy: 1.6) / 1.6
        return Capsule()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 120, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue, .blue.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 48, height: 5)
                    .offset(x: phase * 110 - 20)
            }
            .clipShape(Capsule())
    }
}

#Preview {
    GenerationOrbView(statusText: "Pastel summer landscape")
}
