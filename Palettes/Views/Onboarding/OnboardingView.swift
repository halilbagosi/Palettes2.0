//
//  OnboardingView.swift
//  Palettes
//
//  First-launch onboarding. A step machine over `OnboardingModel`; steps
//  after the orb are placeholders until their tasks land.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var model = OnboardingModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rubber-banded stretch of the island blob while the user pulls down.
    @State private var pull: CGFloat = 0

    private static let islandDiameter: CGFloat = 37
    private static let orbDiameter: CGFloat = 260

    /// The view ignores the safe area (so the orb can start at the very top of
    /// the screen), which zeroes the geometry's insets; read them from the window.
    private static var windowTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    private var detached: Bool { model.step != .pull }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let topInset = Self.windowTopInset
            // Dynamic Island devices have a ~59pt top inset; notch-less ones
            // ~20pt, where the blob rises from just under the status bar.
            let islandY: CGFloat = topInset >= 50
                ? 32
                : topInset + Self.islandDiameter / 2

            ZStack {
                Color(.systemBackground)

                LiquidGradientView(intensity: 0.35)
                    .opacity(detached ? 1 : 0)
                    .animation(.easeInOut(duration: 1.2), value: detached)

                // Catches the pull everywhere on screen during step 0.
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(model.step == .pull ? pullGesture : nil)

                orb(in: size, islandY: islandY)

                content(in: size)

                skipButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, topInset + 52)
                    .padding(.trailing, 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .light), trigger: model.step)
        .onChange(of: model.isFinished) { _, finished in
            if finished { dismiss() }
        }
    }

    // MARK: - Orb

    private func orb(in size: CGSize, islandY: CGFloat) -> some View {
        let diameter = detached ? Self.orbDiameter : Self.islandDiameter + pull * 0.12
        let y = detached ? size.height * 0.4 : islandY + pull
        // Stretch down the pull axis like a drop about to fall.
        let stretch = detached ? 1 : 1 + pull / 500
        // Reduce Motion: no island blob or travel, just a fade in at center.
        let hidden = reduceMotion && !detached

        return OnboardingOrb(diameter: diameter, blackFill: detached ? 0 : 1)
            // Slow black -> clear so the glass reads as filling in after it detaches.
            .animation(.easeInOut(duration: 1.4).delay(reduceMotion ? 0 : 0.25), value: detached)
            .scaleEffect(x: 1 / sqrt(stretch), y: stretch, anchor: .top)
            .position(x: size.width / 2, y: y)
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(detached)
    }

    private var pullGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pull = CGFloat(OnboardingPull.rubberBand(value.translation.height))
            }
            .onEnded { value in
                if OnboardingPull.shouldCommit(translation: value.translation.height) {
                    detach()
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pull = 0 }
                }
            }
    }

    private func detach() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.6)) {
                pull = 0
                model.advance()
            }
        } else {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.72)) {
                pull = 0
                model.advance()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        switch model.step {
        case .pull:
            VStack(spacing: 10) {
                Image(systemName: "chevron.compact.down")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Pull down to begin")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .position(x: size.width / 2, y: size.height * 0.5)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Begins onboarding")
            .accessibilityAction { detach() }
            .transition(.opacity)
        case .orb:
            VStack(spacing: 28) {
                Text("Explore the colors around you.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                continueButton
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .position(x: size.width / 2, y: size.height * 0.78)
            .transition(.opacity)
        default:
            // Camera, adjust, generate, detail and extras land in later tasks.
            VStack(spacing: 28) {
                Text("Step \(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                continueButton
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
            .position(x: size.width / 2, y: size.height * 0.78)
        }
    }

    private var continueButton: some View {
        Button("Continue") {
            withAnimation(.easeInOut(duration: 0.4)) { model.advance() }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var skipButton: some View {
        Button("Skip") { model.skip() }
            .font(.body.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .liquidGlass(.interactive, in: .capsule)
            .accessibilityLabel("Skip onboarding")
    }
}

#Preview {
    OnboardingView()
}
