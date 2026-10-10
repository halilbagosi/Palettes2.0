//
//  PaletteEmpty.swift
//  Palettes
//
//  The app's empty states, in the onboarding's visual language: a glass disc
//  holding the symbol over soft drops of color drifting behind it, a rounded
//  title and a gentle line of copy, and an optional action. `compact` is the
//  smaller form used when filters hide everything.
//

import SwiftUI

struct PaletteEmptyView: View {
    let imageName: String
    var title: String
    let message: String
    var actionTitle: String? = nil
    var actionImage: String = "plus"
    var compact = false
    var action: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: compact ? 18 : 26) {
            EmptyStateArt(symbol: imageName, size: compact ? 92 : 128)
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(compact ? .title2 : .title, design: .rounded).weight(.bold))
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .frame(maxWidth: 320)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)

            if let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionImage)
                        .font(.system(.headline, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .glassButton(prominent: !compact)
                .controlSize(compact ? .regular : .large)
                .tint(.accentColor)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity)
        .offset(y: compact ? 0 : -24)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 12)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(response: 0.6, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }
}

/// A clear glass disc with the symbol, floating over soft drops of color that
/// drift slowly behind it, like the onboarding orb at rest.
struct EmptyStateArt: View {
    var symbol: String
    var size: CGFloat = 128
    /// The drops' colors; a warm-to-cool spread by default.
    var hues: [Color] = EmptyStateArt.defaultHues

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date()
    @State private var bounce = false

    static let defaultHues: [Color] = [
        Color(red: 1.0, green: 0.48, blue: 0.42),
        Color(red: 1.0, green: 0.76, blue: 0.32),
        Color(red: 0.36, green: 0.84, blue: 0.66),
        Color(red: 0.35, green: 0.62, blue: 1.0),
        Color(red: 0.66, green: 0.45, blue: 0.98),
    ]

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
                ZStack {
                    ForEach(Array(hues.enumerated()), id: \.offset) { index, color in
                        let i = Double(index)
                        let angle = i / Double(max(hues.count, 1)) * 2 * .pi + t * 0.22
                        let reach = size * (0.3 + 0.05 * sin(t * 0.5 + i * 1.7))
                        Circle()
                            .fill(color)
                            .frame(width: size * 0.66, height: size * 0.66)
                            .offset(x: reach * cos(angle), y: reach * sin(angle) * 0.8)
                    }
                }
                // A wide blur so the drops melt together, then an eased radial
                // fade so the color thins out into the background with no edge.
                .blur(radius: size * 0.22)
                .frame(width: size * 2.6, height: size * 2.6)
                .mask(SoftFade.radial(endRadius: size * 1.2))
                .opacity(colorScheme == .dark ? 0.5 : 0.6)
            }
            .frame(width: size * 2.6, height: size * 2.6)
            // Lay out at the old footprint; the fade spills past it.
            .frame(width: size * 1.9, height: size * 1.6)

            Image(systemName: symbol)
                .font(.system(size: size * 0.32, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .symbolEffect(.bounce.byLayer, value: bounce)
                .frame(width: size, height: size)
                .liquidGlass(.regular, in: Circle())
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: size * 0.12, y: size * 0.06)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { bounce.toggle() }
        }
    }
}

/// Fades eased with smootherstep, so color thins out gradually instead of
/// ending at a visible line, as a linear gradient does.
enum SoftFade {
    /// Opaque until `start` (0...1 of the way), then easing to clear at the end.
    static func stops(from start: Double = 0, count: Int = 14) -> [Gradient.Stop] {
        (0...count).map { i in
            let x = Double(i) / Double(count)
            let u = min(max((x - start) / (1 - start), 0), 1)
            let fall = u * u * u * (u * (u * 6 - 15) + 10)
            return .init(color: .black.opacity(1 - fall), location: x)
        }
    }

    static func radial(endRadius: CGFloat, from start: Double = 0.15) -> RadialGradient {
        RadialGradient(stops: stops(from: start), center: .center, startRadius: 0, endRadius: endRadius)
    }

    static func linear(from start: Double = 0, _ startPoint: UnitPoint = .top,
                       _ endPoint: UnitPoint = .bottom) -> LinearGradient {
        LinearGradient(stops: stops(from: start), startPoint: startPoint, endPoint: endPoint)
    }
}

#Preview {
    PaletteEmptyView(imageName: "swatchpalette.fill", title: "No palettes yet",
                     message: "Capture colors you love and mix them into your first palette.",
                     actionTitle: "Create Palette")
}
