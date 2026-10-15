//
//  OnboardingWelcome.swift
//  Palettes
//
//  The very first screen: the app icon's three circles on the onboarding
//  background, "Welcome to Palettes" and a Continue button. Continue hands
//  over to the onboarding proper.
//

import SwiftUI

/// Shows the welcome, then onboarding. The two share one background, so the
/// hand-over reads as the circles giving way to the stage.
struct OnboardingEntryView: View {
    let onFinish: (OnboardingFinishReason) -> Void
    @State private var welcomed = false

    var body: some View {
        ZStack {
            if welcomed {
                OnboardingView(onFinish: onFinish)
                    .transition(.opacity)
            } else {
                OnboardingWelcomeView {
                    withAnimation(.easeInOut(duration: 0.5)) { welcomed = true }
                }
                .transition(.blurBridge)
            }
        }
        .background(OnboardingBackground(ambient: 0))
    }
}

struct OnboardingWelcomeView: View {
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// Continue was pressed: the text fades and the circles spiral away.
    @State private var leaving = false

    private func leave() {
        guard !leaving else { return }
        withAnimation(.easeOut(duration: 0.35)) { leaving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 350 : 850))
            onContinue()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            IconCircles(appeared: appeared, leaving: leaving, reduceMotion: reduceMotion)
                .frame(width: 220, height: 220)
                .padding(.bottom, 36)
            VStack(spacing: 14) {
                OnboardingStepText(
                    title: "Welcome to Palettes",
                    subtitle: "Catch the colors you love and turn them into palettes.")
            }
            .opacity(appeared && !leaving ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(.easeOut(duration: 0.6).delay(0.5), value: appeared)
            Spacer(minLength: 0)
            OnboardingPrimaryButton(title: "Continue", systemImage: "arrow.right", action: leave)
                .frame(height: 54)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .opacity(appeared && !leaving ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: appeared)
                .allowsHitTesting(!leaving)
        }
        .padding(.horizontal, 24)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear { appeared = true }
    }
}

/// The icon's coral, amber and violet circles, where they overlap lighter,
/// as in the icon, without its squircle.
private struct IconCircles: View {
    var appeared: Bool
    var leaving: Bool
    var reduceMotion: Bool

    /// Centres on the icon's 1024 grid, radius 269, and the way each one
    /// spirals off: coral up right, amber up left, violet down left.
    private let circles: [(color: Color, center: CGPoint, exit: CGSize)] = [
        (Color(red: 1.0, green: 0.369, blue: 0.478), CGPoint(x: 512, y: 384), CGSize(width: 0.8, height: -1)),
        (Color(red: 1.0, green: 0.690, blue: 0.125), CGPoint(x: 371, y: 614), CGSize(width: -0.8, height: -0.9)),
        (Color(red: 0.478, green: 0.361, blue: 1.0), CGPoint(x: 653, y: 614), CGSize(width: -0.8, height: 1)),
    ]

    var body: some View {
        GeometryReader { geo in
            // The circles span x 102...922, y 115...883 of the 1024 grid.
            let scale = geo.size.width / 820
            ZStack {
                ForEach(Array(circles.enumerated()), id: \.offset) { index, circle in
                    Circle()
                        .fill(circle.color)
                        .frame(width: 538 * scale, height: 538 * scale)
                        .blendMode(.plusLighter)
                        .position(x: appeared || reduceMotion ? (circle.center.x - 512) * scale + geo.size.width / 2 : geo.size.width / 2,
                                  y: appeared || reduceMotion ? (circle.center.y - 614) * scale + geo.size.height * 0.62 : geo.size.height / 2)
                        .scaleEffect(appeared || reduceMotion ? 1 : 0.4)
                        .modifier(SpiralOut(progress: leaving ? 1 : 0, direction: circle.exit,
                                            distance: geo.size.width * 2.6))
                        .opacity(appeared && !leaving ? 0.78 : 0)
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.3)
                                : .spring(response: 0.7, dampingFraction: 0.68).delay(0.1 + Double(index) * 0.1),
                            value: appeared)
                        .animation(reduceMotion ? .easeOut(duration: 0.3) : .easeIn(duration: 0.8)
                            .delay(Double(index) * 0.05), value: leaving)
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
        }
        .accessibilityHidden(true)
    }
}

/// Slides a view away along `direction`, bending the path into a spiral: the
/// offset is turned back by `swirl` at the start and straightens to the exact
/// direction as it goes, and the view shrinks on the way.
private struct SpiralOut: ViewModifier, Animatable {
    var progress: Double
    var direction: CGSize
    var distance: CGFloat
    private let swirl = 0.7

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = CGFloat(progress)
        let angle = swirl * (progress - 1)
        let dx = direction.width * distance * t * t
        let dy = direction.height * distance * t * t
        return content
            .scaleEffect(1 - 0.5 * t)
            .offset(x: dx * cos(angle) - dy * sin(angle),
                    y: dx * sin(angle) + dy * cos(angle))
    }
}

#Preview {
    OnboardingEntryView { _ in }
}
