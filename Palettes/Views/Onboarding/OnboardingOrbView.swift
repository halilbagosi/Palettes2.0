//
//  OnboardingOrbView.swift
//  Palettes
//
//  The onboarding orb: real, clear Liquid Glass (a rim and specular arc before
//  iOS 26) over a small circular window with a feathered edge. The window shows
//  the camera, a photo, or the picked color; the glass lens refracts it and the
//  ambient field behind it. There are no pastel blobs and nothing frosted.
//

import SwiftUI
import Combine
import AVFoundation

/// What the orb's inner window shows.
enum OrbWindowContent {
    case empty
    case camera(OrbCameraController, AVCaptureDevice?)
    case photo(UIImage)
    case color(Color)
    /// One blurred drop per color, drifting slowly.
    case drops([Color])

    /// Changes when the content swaps, so the window cross-fades with a blur bridge.
    var key: String {
        switch self {
        case .empty: "empty"
        case .camera: "camera"
        case .photo(let image): "photo-\(ObjectIdentifier(image).hashValue)"
        case .color: "color"
        case .drops: "drops"
        }
    }
}

struct OnboardingOrbView: View {
    var diameter: CGFloat
    var content: OrbWindowContent = .empty
    var label: String = "Color orb"
    /// Set when the window is a tap target. The tap point is in window coordinates.
    var onWindowTap: ((CGPoint) -> Void)? = nil
    /// White shutter flash inside the window, 0...1.
    var flash: Double = 0
    /// Scale of the window alone (the "you can tap this" pulse).
    var windowScale: CGFloat = 1
    /// Idle wobble liveliness (see `LiquidBubble`).
    var energy: Double = 0.4
    /// Change to make the bubble jiggle.
    var kick: Int = 0
    /// The shadow under the drop, 0...1: 0 while it's still joined to the
    /// island, gathering in as it settles.
    var glow: Double = 1

    @State private var isPressed = false
    /// Local pokes: a tap on the window jiggles the bubble.
    @State private var pokes = 0

    /// Most of the drop: the ink feather fades out well inside this, so the
    /// image melts into the glass instead of stopping at a visible circle.
    static func windowDiameter(for orb: CGFloat) -> CGFloat { orb * 0.86 }

    private var windowDiameter: CGFloat { Self.windowDiameter(for: diameter) }

    private var liquidColors: [Color] {
        switch content {
        case .color(let color): [color]
        case .drops(let colors): colors
        default: []
        }
    }
    private var isTappable: Bool { onWindowTap != nil }

    var body: some View {
        LiquidBubble(diameter: diameter, energy: energy, kick: kick + pokes, pullable: true, glow: glow) {
            ZStack {
                window
                // Colors float in the whole drop, as in the generate orb.
                if !liquidColors.isEmpty {
                    OrbLiquidDrops(colors: liquidColors, diameter: diameter)
                        .transition(.windowSwap)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: content.key)
        }
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 1), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    // MARK: Window

    private var window: some View {
        ZStack {
            // A soft, blurred copy bleeds out past the image's edge, like ink
            // wicking into paper, so its colors carry on into the water.
            // (Not for the live camera: that would mean a second preview.)
            if case .photo = content {
                windowBody
                    .blur(radius: windowDiameter * 0.07)
                    .saturation(1.1)
                    .mask(InkFeather(diameter: windowDiameter, orbDiameter: diameter, reach: 1))
                    .opacity(0.75)
                    .id("bleed-" + content.key)
                    .transition(.windowSwap)
            }
            windowBody
                .mask(InkFeather(diameter: windowDiameter, orbDiameter: diameter, reach: 0.8))
                .id(content.key)
                .transition(.windowSwap)
            Circle()
                .fill(.white)
                .opacity(flash)
                .mask(InkFeather(diameter: windowDiameter, orbDiameter: diameter, reach: 0.8))
                .allowsHitTesting(false)
        }
        .frame(width: windowDiameter, height: windowDiameter)
        .scaleEffect(windowScale)
        .contentShape(Circle())
        .gesture(tapGesture, including: isTappable ? .all : .none)
        .accessibilityAddTraits(isTappable ? .isButton : [])
        .animation(.easeInOut(duration: 0.4), value: content.key)
    }

    @ViewBuilder
    private var windowBody: some View {
        switch content {
        case .empty:
            Color.clear
        case .camera(let controller, let device):
            OrbCameraPreview(controller: controller, device: device)
                .frame(width: windowDiameter, height: windowDiameter)
                .clipped()
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: windowDiameter, height: windowDiameter)
                .clipped()
        case .color, .drops:
            // Drawn across the whole drop, outside the feathered window.
            Color.clear
        }
    }

    private var tapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { value in
                isPressed = false
                pokes += 1
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 12 { onWindowTap?(value.location) }
            }
    }

}

// MARK: - Window pieces

/// The window's mask: a circle whose density thins out along a long, eased
/// falloff (no ring where the fade starts), so the image soaks into the
/// glass like ink. It wobbles with the bubble around it, taking the same
/// oval, turn and drift each frame. `reach` scales how far it spreads
/// (1 fills the window).
struct InkFeather: View {
    var diameter: CGFloat
    /// The bubble's diameter, which the wobble's drift is a fraction of.
    var orbDiameter: CGFloat
    var reach: CGFloat = 1
    @Environment(\.bubbleWobble) private var wobble

    /// 1 at the center, easing (smootherstep) to 0 at the edge from 20% out.
    private static let stops: [Gradient.Stop] = (0...12).map { i in
        let x = Double(i) / 12
        let u = min(max((x - 0.2) / 0.8, 0), 1)
        let fall = u * u * u * (u * (u * 6 - 15) + 10)
        return .init(color: .black.opacity(1 - fall), location: x)
    }

    var body: some View {
        // Same deformation as `BubbleShape`: an area-keeping ellipse along
        // the oval's angle, shifted with the drop's center.
        let a = 1 + wobble.oval
        Circle()
            .fill(RadialGradient(stops: Self.stops, center: .center,
                                 startRadius: 0, endRadius: diameter / 2 * reach))
            .frame(width: diameter, height: diameter)
            .scaleEffect(x: a, y: 1 / a)
            .rotationEffect(.radians(wobble.ovalAngle))
            .offset(x: wobble.drift.width * orbDiameter,
                    y: wobble.drift.height * orbDiameter)
            .frame(width: diameter, height: diameter)
            .allowsHitTesting(false)
    }
}

private struct WindowSwap: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 6)
    }
}

private extension Transition where Self == WindowSwap {
    static var windowSwap: WindowSwap { WindowSwap() }
}

/// Soft drops of color drifting inside the drop, drawn exactly like the
/// generate orb's liquid: each drop half the orb wide at 70% opacity, orbiting
/// slowly, blurred together and a little more saturated. A drop arriving scales in.
struct OrbLiquidDrops: View {
    var colors: [Color]
    var diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSince(start)
            ZStack {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Circle()
                        .fill(color.opacity(0.7))
                        .frame(width: diameter * 0.52, height: diameter * 0.52)
                        .offset(drift(index: index, time: t, orbit: diameter * 0.19))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.07)
            .saturation(1.2)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: colors.count)
        }
    }

    /// Slow orbital drift, unique per drop (the generate orb's).
    private func drift(index: Int, time t: Double, orbit: CGFloat) -> CGSize {
        let i = Double(index)
        let speed = 0.55 + 0.06 * i.truncatingRemainder(dividingBy: 3)
        return CGSize(width: orbit * sin(t * speed + i * 2.4),
                      height: orbit * cos(t * (speed * 0.8) + i * 1.7))
    }
}
