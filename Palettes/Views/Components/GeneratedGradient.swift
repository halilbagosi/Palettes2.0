import Combine
import Foundation
import SwiftUI

/// The animated spectrum used by Apple Intelligence-generated content.
///
/// Keeping the palette and mesh motion here means generated badges and the
/// generation form's glyph always share the same visual language.
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

    @available(iOS 26.0, *)
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

    @available(iOS 26.0, *)
    private static func colors(for phase: CGFloat) -> [Color] {
        let normalizedPhase = Double(phase)
        let angle = normalizedPhase * .pi * 2

        // Add small, per-stop waves to make the color travel feel organic
        // while keeping every transition continuous at the cycle endpoints.
        return zip(paletteA, paletteB).enumerated().map { index, pair in
            let offset = Double(index) * 0.73
            let variation = (
                0.12 * sin(angle * 2 + offset)
                + 0.05 * cos(angle * 3 - offset * 0.4)
            ) * sin(.pi * normalizedPhase)
            let blend = min(max(normalizedPhase + variation, 0), 1)

            let first = pair.0
            let second = pair.1
            return Color(
                red: first.red + (second.red - first.red) * blend,
                green: first.green + (second.green - first.green) * blend,
                blue: first.blue + (second.blue - first.blue) * blend
            )
        }
    }

    // Bright pastel colors with more red and blue, a smaller gold center,
    // less green, and a more visible violet finish.
    private static let paletteA: [(red: Double, green: Double, blue: Double)] = [
        (0.92, 0.30, 0.46), (0.96, 0.42, 0.50), (0.96, 0.58, 0.48),
        (0.88, 0.46, 0.58), (0.92, 0.72, 0.50), (0.68, 0.72, 0.58),
        (0.44, 0.68, 0.82), (0.38, 0.60, 0.90), (0.58, 0.48, 0.92)
    ]

    private static let paletteB: [(red: Double, green: Double, blue: Double)] = [
        (1.00, 0.38, 0.58), (1.00, 0.50, 0.62), (1.00, 0.66, 0.54),
        (0.96, 0.54, 0.66), (0.98, 0.80, 0.60), (0.76, 0.80, 0.70),
        (0.56, 0.78, 0.92), (0.50, 0.70, 0.98), (0.70, 0.60, 1.00)
    ]
}

enum GeneratedBadgeAnimationScope: Hashable {
    case colors
    case palettes
}

/// One shared animation clock for generated badges in the library tabs.
///
/// The source only ticks while the active tab has at least one visible
/// generated card. Individual badges subscribe to the source only while their
/// own card intersects the tab's scroll viewport.
@MainActor
final class GeneratedBadgeAnimationSource: ObservableObject {
    @Published private(set) var phase: CGFloat = 0.5

    private var activeScope: GeneratedBadgeAnimationScope?
    private var visibleIDsByScope: [GeneratedBadgeAnimationScope: Set<UUID>] = [:]
    private var animationTask: Task<Void, Never>?

    func setActiveScope(_ scope: GeneratedBadgeAnimationScope?) {
        guard activeScope != scope else { return }
        activeScope = scope
        updateAnimationTask()
    }

    func updateVisibleIDs(
        _ ids: Set<UUID>,
        for scope: GeneratedBadgeAnimationScope
    ) {
        guard visibleIDsByScope[scope] != ids else { return }
        visibleIDsByScope[scope] = ids
        updateAnimationTask()
    }

    private var activeVisibleIDs: Set<UUID> {
        guard let activeScope else { return [] }
        return visibleIDsByScope[activeScope] ?? []
    }

    private func updateAnimationTask() {
        guard !activeVisibleIDs.isEmpty else {
            animationTask?.cancel()
            animationTask = nil
            return
        }

        guard animationTask == nil else { return }

        animationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.phase = GeneratedGradient.phase(at: Date())
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }

    deinit {
        animationTask?.cancel()
    }
}

private struct GeneratedBadgeAnimationSourceKey: EnvironmentKey {
    static let defaultValue: GeneratedBadgeAnimationSource? = nil
}

extension EnvironmentValues {
    var generatedBadgeAnimationSource: GeneratedBadgeAnimationSource? {
        get { self[GeneratedBadgeAnimationSourceKey.self] }
        set { self[GeneratedBadgeAnimationSourceKey.self] = newValue }
    }
}

struct GeneratedBadgeVisibilityFrame: Equatable {
    let id: UUID
    let frame: CGRect
}

struct GeneratedBadgeVisibilityPreferenceKey: PreferenceKey {
    static let defaultValue: [GeneratedBadgeVisibilityFrame] = []

    static func reduce(
        value: inout [GeneratedBadgeVisibilityFrame],
        nextValue: () -> [GeneratedBadgeVisibilityFrame]
    ) {
        value.append(contentsOf: nextValue())
    }
}

enum GeneratedBadgeVisibility {
    static let colorsCoordinateSpace = "ColorsView.GeneratedBadgeViewport"
    static let palettesCoordinateSpace = "PaletteView.GeneratedBadgeViewport"

    static func visibleIDs(
        from frames: [GeneratedBadgeVisibilityFrame],
        viewportSize: CGSize
    ) -> Set<UUID> {
        let viewport = CGRect(origin: .zero, size: viewportSize)
        return Set(
            frames
                .filter { $0.frame.intersects(viewport) }
                .map(\.id)
        )
    }
}

struct GeneratedBadgeVisibilityModifier: ViewModifier {
    let id: UUID
    let coordinateSpace: String
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: GeneratedBadgeVisibilityPreferenceKey.self,
                        value: [
                            GeneratedBadgeVisibilityFrame(
                                id: id,
                                frame: proxy.frame(in: .named(coordinateSpace))
                            )
                        ]
                    )
                }
            }
        } else {
            content
        }
    }
}

extension View {
    func generatedBadgeVisibility(
        id: UUID,
        in coordinateSpace: String,
        isEnabled: Bool
    ) -> some View {
        modifier(
            GeneratedBadgeVisibilityModifier(
                id: id,
                coordinateSpace: coordinateSpace,
                isEnabled: isEnabled
            )
        )
    }
}

@available(iOS 26.0, *)
struct GeneratedBadge: View {
    let isCompact: Bool
    var isVisible: Bool = false

    @Environment(\.generatedBadgeAnimationSource) private var animationSource

    var body: some View {
        if isVisible, let animationSource {
            AnimatedGeneratedBadge(isCompact: isCompact, source: animationSource)
        } else {
            GeneratedBadgeContent(isCompact: isCompact, phase: 0.5)
        }
    }
}

@available(iOS 26.0, *)
private struct AnimatedGeneratedBadge: View {
    let isCompact: Bool
    @ObservedObject var source: GeneratedBadgeAnimationSource

    var body: some View {
        GeneratedBadgeContent(isCompact: isCompact, phase: source.phase)
    }
}

@available(iOS 26.0, *)
private struct GeneratedBadgeContent: View {
    let isCompact: Bool
    let phase: CGFloat

    var body: some View {
        HStack(spacing: isCompact ? 0 : 6) {
            Image(systemName: "apple.intelligence")
                .font(.subheadline.weight(.semibold))

            if !isCompact {
                Text("Generated")
                    .font(.caption.weight(.semibold))
            }
        }
        .foregroundStyle(GeneratedGradient.style(phase: phase))
        .padding(.horizontal, isCompact ? 9 : 10)
        .padding(.vertical, 7)
        .frame(minHeight: 34)
        .liquidGlass(.regular, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Apple Intelligence Generated")
        .allowsHitTesting(false)
    }
}
