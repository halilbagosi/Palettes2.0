//
//  OnboardingGlassLab.swift
//  Palettes
//
//  DEBUG-only: a grid of glass-orb variants over the ambient field, for
//  isolating what makes clear glass render white. `-onboardingGlassLab YES`.
//

#if DEBUG
import SwiftUI

@available(iOS 26.0, *)
struct OnboardingGlassLab: View {
    private let size: CGFloat = 170

    private static func tone(_ hue: Double, _ sat: Double = 0.5, _ bri: Double = 1) -> Color {
        Color(hue: hue, saturation: sat, brightness: bri)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 28) {
                haloCell("a shader 1.0") { LiquidGradientView(intensity: 1) }
                haloCell("b colors .6 sat .5") {
                    LiquidGradientView(intensity: 0.6, colors: [Self.tone(0.95), Self.tone(0.07), Self.tone(0.75), Self.tone(0.5)])
                }
                haloCell("c colors .9 sat .6") {
                    LiquidGradientView(intensity: 0.9, colors: [Self.tone(0.95, 0.6), Self.tone(0.07, 0.6), Self.tone(0.75, 0.6), Self.tone(0.5, 0.6)])
                }
                haloCell("d colors 1.0 sat .35") {
                    LiquidGradientView(intensity: 1, colors: [Self.tone(0.95, 0.35), Self.tone(0.07, 0.35), Self.tone(0.75, 0.35), Self.tone(0.5, 0.35)])
                }
                haloCell("e base+halo") {
                    ZStack {
                        LiquidGradientView(intensity: 0.25)
                        LiquidGradientView(intensity: 0.9, colors: [Self.tone(0.95, 0.55), Self.tone(0.07, 0.55), Self.tone(0.75, 0.55), Self.tone(0.5, 0.55)])
                            .mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 30, endRadius: 150))
                    }
                }
                haloCell("f colors .6 + photo") {
                    LiquidGradientView(intensity: 0.6, colors: [Self.tone(0.95), Self.tone(0.07), Self.tone(0.75), Self.tone(0.5)])
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// The real orb over a candidate ambient field.
    private func haloCell<B: View>(_ title: String, @ViewBuilder _ backdrop: () -> B) -> some View {
        cell(title) {
            ZStack {
                backdrop().frame(width: size + 40, height: size + 40).clipped()
                OnboardingOrbView(diameter: size - 20,
                                  content: title.hasPrefix("f") ? .photo(OnboardingSampleImage.shared) : .empty)
            }
        }
    }

    private func cell<V: View>(_ title: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 6) {
            content().frame(width: size, height: size)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
#endif
