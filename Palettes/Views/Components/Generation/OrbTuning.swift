//
//  OrbTuning.swift
//  Palettes
//
//  Every tunable number of the orb (generate + onboarding). Release builds use
//  the defaults; DEBUG builds read live values from `OrbDebugSettings`, which a
//  triple tap on any orb opens a panel for.
//

import SwiftUI
import Combine

struct OrbTuning: Equatable {
    // Idle wobble
    var wobbleSpeed = 1.0
    var idleOval = 0.024
    var idleOvalSwell = 0.024
    var idleLobe = 0.008
    var idleDrift = 0.0075
    // Pull + release spring
    var pullAmount = 0.42
    var pullShift = 0.22
    var releaseResponse = 0.42
    var releaseDamping = 0.26
    // Rim refraction
    var glassRefraction = 0.7
    var refractionPower = 10.0
    // Shadow under the drop
    var shadowOpacity = 1.0
    var shadowBlur = 1.0
    // Color drops inside
    var dropSpeed = 0.7
    var dropOrbit = 0.2
    var dropSize = 0.52
    var dropOpacity = 0.7
    var dropBlur = 0.07
    var dropSaturation = 1.2
    // Onboarding window
    var windowSize = 0.86
    var featherStart = 0.2
    var featherReach = 0.8

    static var live: OrbTuning {
#if DEBUG
        MainActor.assumeIsolated { OrbDebugSettings.shared.tuning }
#else
        OrbTuning()
#endif
    }
}

#if DEBUG
@MainActor
final class OrbDebugSettings: ObservableObject {
    static let shared = OrbDebugSettings()
    @Published var tuning = OrbTuning()
}

struct OrbDebugPanel: View {
    @ObservedObject var settings: OrbDebugSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Idle wobble") {
                    row("Speed", \.wobbleSpeed, 0...3)
                    row("Oval squash", \.idleOval, 0...0.15)
                    row("Oval swell", \.idleOvalSwell, 0...0.15)
                    row("Lobes", \.idleLobe, 0...0.06)
                    row("Center drift", \.idleDrift, 0...0.05)
                }
                Section("Pull & release") {
                    row("Pull amount", \.pullAmount, 0...0.8)
                    row("Pull shift", \.pullShift, 0...0.5)
                    row("Release response", \.releaseResponse, 0.1...1)
                    row("Release damping", \.releaseDamping, 0.05...1)
                }
                Section("Rim refraction") {
                    row("Strength", \.glassRefraction, 0...1)
                    row("Falloff power (low = wider)", \.refractionPower, 1...16)
                }
                Section("Shadow") {
                    row("Opacity", \.shadowOpacity, 0...3)
                    row("Blur", \.shadowBlur, 0...3)
                }
                Section("Color drops") {
                    row("Speed", \.dropSpeed, 0...3)
                    row("Orbit", \.dropOrbit, 0...0.5)
                    row("Size", \.dropSize, 0.2...1)
                    row("Opacity", \.dropOpacity, 0...1)
                    row("Blur", \.dropBlur, 0...0.2)
                    row("Saturation", \.dropSaturation, 0...2.5)
                }
                Section("Onboarding window") {
                    row("Window size", \.windowSize, 0.4...1)
                    row("Feather start", \.featherStart, 0...0.9)
                    row("Feather reach", \.featherReach, 0.3...1.3)
                }
                Section {
                    Button("Reset to defaults", role: .destructive) { settings.tuning = OrbTuning() }
                }
            }
            .navigationTitle("Orb Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ label: String, _ key: WritableKeyPath<OrbTuning, Double>,
                     _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.3f", settings.tuning[keyPath: key]))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { settings.tuning[keyPath: key] },
                                  set: { settings.tuning[keyPath: key] = $0 }), in: range)
        }
    }
}
#endif

extension View {
    /// Triple tap opens the orb tuning panel (DEBUG builds only).
    @ViewBuilder
    func orbDebugMenu() -> some View {
#if DEBUG
        modifier(OrbDebugMenu())
#else
        self
#endif
    }
}

#if DEBUG
private struct OrbDebugMenu: ViewModifier {
    @State private var show = false
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture(count: 3).onEnded { show = true })
            .sheet(isPresented: $show) {
                OrbDebugPanel(settings: .shared)
                    .presentationDetents([.medium, .large])
            }
    }
}
#endif
