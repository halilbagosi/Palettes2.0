//
//  OnboardingView.swift
//  Palettes
//
//  First-launch onboarding. A step machine over `OnboardingModel`; steps
//  after the orb are placeholders until their tasks land. The presenter
//  dismisses the cover in response to `onFinish`.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Rubber-banded stretch of the island blob while the user pulls down.
    @State private var pull: CGFloat = 0

    private static let islandDiameter: CGFloat = 37
    private static let maxOrbDiameter: CGFloat = 260
    /// Dynamic Island center, measured from the top of the screen.
    private static let islandCenterY: CGFloat = 32
    /// Skip's distance below the top safe-area edge. Larger on island devices
    /// so it clears the island's neighborhood; small elsewhere.
    private static let skipTopPaddingIsland: CGFloat = 44
    private static let skipTopPaddingDefault: CGFloat = 8
    private static let skipHeight: CGFloat = 44

    init(onFinish: @escaping (OnboardingFinishReason) -> Void) {
        _model = StateObject(wrappedValue: OnboardingModel(onFinish: onFinish))
    }

    private var detached: Bool { model.step != .pull }

    /// Geometry shared by the orb layer and the captions below it.
    private struct Layout {
        let full: CGSize
        let topInset: CGFloat
        let bottomInset: CGFloat
        let hasIsland: Bool

        var skipTopPadding: CGFloat {
            hasIsland ? OnboardingView.skipTopPaddingIsland : OnboardingView.skipTopPaddingDefault
        }
        var orbDiameter: CGFloat { min(OnboardingView.maxOrbDiameter, full.height * 0.45) }
        /// Screen-space top of the settled orb: below Skip.
        var orbTop: CGFloat { topInset + skipTopPadding + OnboardingView.skipHeight + 8 }
        var orbCenter: CGPoint { CGPoint(x: full.width / 2, y: orbTop + orbDiameter / 2) }
        /// Safe-area-space height reserved above the captions.
        var captionTopInset: CGFloat { orbTop - topInset + orbDiameter + 24 }
    }

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let full = CGSize(
                width: geo.size.width + insets.leading + insets.trailing,
                height: geo.size.height + insets.top + insets.bottom
            )
            let layout = Layout(
                full: full,
                topInset: insets.top,
                bottomInset: insets.bottom,
                // Portrait Dynamic Island devices have a ~59pt top inset;
                // notch-less ones ~20pt and landscape ~0.
                hasIsland: insets.top >= 50 && full.height > full.width
            )
            // Reduce Motion, landscape, and island-less devices just fade the
            // orb in at its settled position.
            let travels = layout.hasIsland && !reduceMotion

            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                Group {
                    if detached {
                        LiquidGradientView(intensity: 0.35)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 1.2), value: detached)

                // Catches the pull everywhere on screen during step 0.
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(model.step == .pull ? pullGesture(travels: travels) : nil)

                // Full-screen coordinate space for the orb.
                Color.clear
                    .ignoresSafeArea()
                    .overlay { ZStack { orbLayer(layout: layout, travels: travels) }.ignoresSafeArea() }
                    .allowsHitTesting(false)

                content(layout: layout, travels: travels)

                skipButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, layout.skipTopPadding)
                    .padding(.trailing, 20)
                    .accessibilitySortPriority(1)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.step)
    }

    // MARK: - Orb

    @ViewBuilder
    private func orbLayer(layout: Layout, travels: Bool) -> some View {
        if travels {
            let diameter = detached ? layout.orbDiameter : Self.islandDiameter + pull * 0.12
            let y = detached ? layout.orbCenter.y : Self.islandCenterY + pull
            // Stretch down the pull axis like a drop about to fall.
            let stretch = detached ? 1 : 1 + pull / 500

            OnboardingOrb(diameter: diameter, blackFill: detached ? 0 : 1, label: orbLabel)
                // Slow black -> clear so the glass reads as filling in after it detaches.
                .animation(.easeInOut(duration: 1.4).delay(0.25), value: detached)
                .scaleEffect(x: 1 / sqrt(stretch), y: stretch, anchor: .top)
                .position(x: layout.orbCenter.x, y: y)
        } else if detached {
            OnboardingOrb(diameter: layout.orbDiameter, blackFill: 0, label: orbLabel)
                .position(layout.orbCenter)
                .transition(.opacity)
        }
    }

    private var orbLabel: String {
        switch model.step {
        case .pull: "Orb at the top of the screen"
        case .orb: "Color orb"
        case .camera: "Camera preview orb"
        case .adjust: "Scanned color orb"
        case .generate: "Palette orb"
        }
    }

    private func pullGesture(travels: Bool) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard travels else { return }
                pull = CGFloat(OnboardingPull.rubberBand(value.translation.height))
            }
            .onEnded { value in
                if OnboardingPull.shouldCommit(
                    translation: value.translation.height,
                    predictedEnd: value.predictedEndTranslation.height
                ) {
                    detach(travels: travels)
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pull = 0 }
                }
            }
    }

    private func detach(travels: Bool) {
        if travels {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.72)) {
                pull = 0
                model.advance()
            }
        } else {
            withAnimation(.easeInOut(duration: 0.6)) {
                pull = 0
                model.advance()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(layout: Layout, travels: Bool) -> some View {
        if model.step == .pull {
            VStack(spacing: 10) {
                Image(systemName: "chevron.compact.down")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("Pull down to begin")
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // No drag required when the orb doesn't travel from the island.
                if !travels {
                    Button("Begin") { detach(travels: false) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: travels ? .combine : .contain)
            .accessibilityAddTraits(travels ? .isButton : [])
            .accessibilityHint(travels ? "Begins onboarding" : "")
            .accessibilityAction { detach(travels: travels) }
            .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                Color.clear.frame(height: layout.captionTopInset)
                ScrollView {
                    captions
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .id(model.step)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var captions: some View {
        VStack(spacing: 28) {
            switch model.step {
            case .orb:
                Text("Explore the colors around you.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                continueButton
            case .generate:
                // Placeholder: Task 4 finishes with `.completed(paletteID:)`.
                Text("Step \(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Finish") { model.skip() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            default:
                // Camera and adjust land in later tasks.
                Text("Step \(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                continueButton
            }
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
            .glassCapsuleButton()
            .accessibilityLabel("Skip onboarding")
    }
}

#Preview {
    OnboardingView { _ in }
}
