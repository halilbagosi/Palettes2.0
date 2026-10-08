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

    @State private var isPressed = false

    static func windowDiameter(for orb: CGFloat) -> CGFloat { orb * 0.56 }
    /// The liquid color fill grows to this fraction of the orb.
    static let colorFillFraction: CGFloat = 0.78

    private var windowDiameter: CGFloat { Self.windowDiameter(for: diameter) }
    private var isTappable: Bool { onWindowTap != nil }

    var body: some View {
        ZStack {
            shadowRing
            window
            if case .color(let color) = content {
                OrbLiquidFill(color: color, size: diameter * Self.colorFillFraction)
                    .transition(.windowSwap)
                    .allowsHitTesting(false)
            }
            glass
        }
        .animation(.easeInOut(duration: 0.4), value: content.key)
        .frame(width: diameter, height: diameter)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 1), value: isPressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    // MARK: Window

    private var window: some View {
        ZStack {
            windowBody
                .id(content.key)
                .transition(.windowSwap)
            Circle()
                .fill(.white)
                .opacity(flash)
                .allowsHitTesting(false)
        }
        .frame(width: windowDiameter, height: windowDiameter)
        .mask(feather)
        .scaleEffect(windowScale)
        .contentShape(Circle())
        .gesture(tapGesture, including: isTappable ? .all : .none)
        .accessibilityAddTraits(isTappable ? .isButton : [])
        .animation(.easeInOut(duration: 0.4), value: content.key)
    }

    /// Radial feather: solid to 55% of the radius, clear at the rim.
    private var feather: some View {
        RadialGradient(
            stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
            center: .center, startRadius: 0, endRadius: windowDiameter / 2
        )
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
        case .color:
            // Drawn outside the window, so the feather doesn't clip its growth.
            Color.clear
        case .drops(let colors):
            OrbDrops(colors: colors)
                .frame(width: windowDiameter, height: windowDiameter)
        }
    }

    private var tapGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded { value in
                isPressed = false
                let moved = hypot(value.translation.width, value.translation.height)
                if moved < 12 { onWindowTap?(value.location) }
            }
    }

    // MARK: Glass

    @ViewBuilder
    private var glass: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.clear.interactive(isTappable), in: .circle)
                .allowsHitTesting(false)
        } else {
            LegacyGlassShell()
                .allowsHitTesting(false)
        }
    }

    /// A soft shadow under the orb only: a ring with the orb's body cut out, so it
    /// never tints the clear glass.
    private var shadowRing: some View {
        let strength = Easing.smoothstep(40, 200, Double(diameter))
        return Circle()
            .fill(.black.opacity(0.12 * strength))
            .frame(width: diameter, height: diameter)
            .blur(radius: 24)
            .offset(y: 12)
            .mask {
                Rectangle()
                    .fill(.black)
                    .overlay { Circle().fill(.black).frame(width: diameter, height: diameter).blendMode(.destinationOut) }
                    .compositingGroup()
                    .frame(width: diameter + 400, height: diameter + 400)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Window pieces

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

/// The picked color as liquid in the orb: a disc with a soft radial highlight
/// that grows into place.
struct OrbLiquidFill: View {
    var color: Color
    var size: CGFloat
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = grown || reduceMotion
        Circle()
            .fill(color)
            .overlay {
                Circle().fill(RadialGradient(
                    colors: [.white.opacity(0.35), .clear],
                    center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: size * 0.55))
            }
            .frame(width: size, height: size)
            .scaleEffect(shown ? 1 : 0.72)
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.9), value: shown)
            .onAppear { grown = true }
    }
}

/// Drifting, blurred drops, one per color.
struct OrbDrops: View {
    var colors: [Color]
    private let start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSince(start)
            GeometryReader { geo in
                let side = geo.size.width
                ZStack {
                    ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                        let phase = Double(index) * 1.7
                        Circle()
                            .fill(color)
                            .frame(width: side * 0.62, height: side * 0.62)
                            .offset(x: CGFloat(sin(time * 0.5 + phase)) * side * 0.16,
                                    y: CGFloat(cos(time * 0.42 + phase * 1.3)) * side * 0.16)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
                .frame(width: side, height: side)
                .blur(radius: side * 0.1)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: colors.count)
            }
        }
    }
}

/// Clear glass for iOS 17-25: a 1 pt rim, a specular arc at the top-left and a
/// faint inner shadow at the bottom edge. No frosting.
private struct LegacyGlassShell: View {
    var body: some View {
        GeometryReader { geo in
            let d = geo.size.width
            ZStack {
                // Inner shadow, bottom edge.
                Circle()
                    .strokeBorder(
                        LinearGradient(colors: [.clear, .black.opacity(0.14)],
                                       startPoint: UnitPoint(x: 0.5, y: 0.55), endPoint: .bottom),
                        lineWidth: d * 0.05)
                    .blur(radius: d * 0.02)
                    .clipShape(Circle())
                // Specular arc.
                Ellipse()
                    .fill(.white.opacity(0.35))
                    .frame(width: d * 0.42, height: d * 0.16)
                    .blur(radius: d * 0.035)
                    .rotationEffect(.degrees(-38))
                    .offset(x: -d * 0.2, y: -d * 0.3)
                    .clipShape(Circle())
                // Rim.
                Circle().strokeBorder(
                    AngularGradient(
                        colors: [.white.opacity(0.7), .white.opacity(0.1), .white.opacity(0.5), .white.opacity(0.7)],
                        center: .center),
                    lineWidth: 1)
            }
        }
    }
}

#Preview("Glass orb") {
    ZStack {
        LiquidGradientView(intensity: 0.4).ignoresSafeArea()
        VStack(spacing: 30) {
            OnboardingOrbView(diameter: 260)
            OnboardingOrbView(diameter: 260, content: .photo(OnboardingSampleImage.shared))
        }
    }
}
