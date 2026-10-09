//
//  OnboardingView.swift
//  Palettes
//
//  First-launch onboarding coordinator. A step machine over `OnboardingModel`:
//  pull, orb, camera (or sample/photo fallback), adjust, and generate. It owns
//  the layout: the orb at 38% of the height, the step's text just under it, and the primary action pinned at the bottom. The island morph, the
//  orb, and each step's content live in their own files. Finishing saves the
//  palette through `AppData`; the presenter dismisses the cover in response to
//  `onFinish`.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var model: OnboardingModel
    @StateObject private var flow: OnboardingCameraFlow
    @StateObject private var interim: OnboardingInterimFlow
    @StateObject private var morph = IslandMorphController(
        placement: .init(island: .none, screenWidth: 0, restCenter: .zero, restDiameter: 0))

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var appData: AppData

    /// The ambient field's opacity; it fades in once the orb starts detaching.
    @State private var ambient: Double = 0
    /// The orb has landed: the text, buttons and Skip are shown.
    @State private var landed = false

    private var skipVisible: Bool { landed || model.step == .pull }

    init(onFinish: @escaping (OnboardingFinishReason) -> Void) {
        let start = OnboardingDebug.start
        let model = OnboardingModel(startingAt: start.step, onFinish: onFinish)
        start.prepare(model)
        _model = StateObject(wrappedValue: model)
        _flow = StateObject(wrappedValue: OnboardingCameraFlow(model: model))
        _interim = StateObject(wrappedValue: OnboardingInterimFlow(model: model))
        _landed = State(initialValue: start.step != .pull)
        _ambient = State(initialValue: start.step != .pull ? 1 : 0)
    }

    // MARK: Layout

    private struct Layout {
        let full: CGSize
        let topInset: CGFloat
        let island: IslandGeometry
        let compact: Bool

        var orbDiameter: CGFloat {
            compact ? min(240, full.width * 0.62) : min(310, full.width * 0.76)
        }
        /// Skip's pill: 6 below the top safe area, 30 tall.
        var skipBottom: CGFloat { topInset + 6 + 30 }
        var restCenter: CGPoint {
            // 38% of the height; short screens keep the orb higher to leave room for the text.
            let y = max(full.height * (full.height < 700 ? 0.34 : 0.38), skipBottom + 12 + orbDiameter / 2)
            return CGPoint(x: full.width / 2, y: y)
        }
        /// Safe-area-space top of the text region, under the orb.
        var contentTop: CGFloat { restCenter.y + orbDiameter / 2 + 28 - topInset }
        var placement: IslandMorphController.Placement {
            .init(island: island, screenWidth: full.width, restCenter: restCenter, restDiameter: orbDiameter)
        }
        var windowDiameter: CGFloat { OnboardingOrbView.windowDiameter(for: orbDiameter) }
    }

    var body: some View {
        #if DEBUG
        if OnboardingDebug.glassLab, #available(iOS 26.0, *) {
            OnboardingGlassLab()
        } else {
            onboardingBody
        }
        #else
        onboardingBody
        #endif
    }

    private var onboardingBody: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let full = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                              height: geo.size.height + insets.top + insets.bottom)
            let layout = Layout(
                full: full,
                topInset: insets.top,
                island: .make(topInset: insets.top, screenSize: full),
                compact: dynamicTypeSize.isAccessibilitySize || full.height < 700
            )
            // Reduce Motion, landscape and island-less phones fade the orb in at rest.
            let travels = layout.island.hasMorph && !reduceMotion
            let _ = morph.placement = layout.placement

            ZStack {
                PullDrivenBackground(pull: morph.pull, ambient: ambient)

                if model.step == .pull && travels {
                    pullGestureLayer
                    PullPrompt(pull: morph.pull)
                        .position(layout.restCenter)
                        .transition(.opacity)
                        .accessibilityAction { morph.useFadeMode(); morph.beginFade() }
                }

                IslandMorphStage(controller: morph) { diameter in
                    orb(diameter: diameter, layout: layout)
                }

                if !(model.step == .pull && travels) {
                    stepLayer(layout: layout, content: content(travels: travels))
                }

                OnboardingSkipButton { model.skip() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 6 - 7)
                    .padding(.trailing, 20 - 7)
                    // Always reachable, except while the orb is travelling to its place.
                    .opacity(skipVisible ? 1 : 0)
                    .allowsHitTesting(skipVisible)
                    .animation(.easeOut(duration: 0.3), value: skipVisible)
            }
            .animation(.easeOut(duration: 0.3), value: model.step == .pull)
            .onChange(of: travels, initial: true) { _, travels in
                if !travels { morph.useFadeMode() }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: flow.scanCount)
        .onAppear {
            morph.onCommit = {
                withAnimation(.easeOut(duration: 0.8)) { ambient = 1 }
                model.advance()
            }
            morph.onLand = { withAnimation(.easeOut(duration: 0.4)) { landed = true } }
            // A Settings-triggered debug start is single-use.
            OnboardingDebug.clearSettingsRequest()
            if landed { morph.landImmediately() }
            if let hold = OnboardingDebug.pullHold { morph.debugHold(pull: hold) }
            if model.step == .camera { flow.refreshAccess() }
            if model.step == .adjust || model.step == .generate { interim.beginAdjust() }
            if model.step == .generate { interim.startGeneration(appData: appData, reduceMotion: reduceMotion) }
            flow.updateSession()
            if OnboardingDebug.autoBegin, model.step == .pull {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    morph.useFadeMode()
                    morph.beginFade()
                }
            }
        }
        .onChange(of: model.step) { _, step in
            if step == .camera { flow.refreshAccess() }
            if step == .adjust { interim.beginAdjust() }
            flow.updateSession()
        }
        .onChange(of: scenePhase) { _, phase in
            flow.setSceneActive(phase == .active)
            // The user may have changed access in Settings while away.
            if phase == .active, model.step == .camera, model.capturedImage == nil {
                flow.refreshAccess()
            }
        }
        .onChange(of: model.cameraAccess) { _, _ in flow.updateSession() }
        .onChange(of: flow.photosPickerItem) { _, _ in flow.loadPickedPhoto() }
        .onDisappear {
            flow.stop()
            interim.stop()
        }
    }

    // MARK: Pull

    /// Catches the pull everywhere on screen during the first step.
    private var pullGestureLayer: some View {
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { morph.dragChanged(translation: $0.translation.height, time: $0.time.timeIntervalSinceReferenceDate) }
                    .onEnded { morph.dragEnded(time: $0.time.timeIntervalSinceReferenceDate) }
            )
    }

    // MARK: Orb

    private func orb(diameter: CGFloat, layout: Layout) -> some View {
        let windowDiameter = OnboardingOrbView.windowDiameter(for: diameter)
        return ZStack {
            OnboardingOrbView(
                diameter: diameter,
                content: orbContent,
                label: orbLabel,
                onWindowTap: windowTap(windowDiameter: windowDiameter),
                flash: flow.flash,
                windowScale: flow.windowScale,
                // Livelier while the camera is live or a palette is generating.
                energy: orbEnergy,
                kick: flow.scanCount
            )
            if model.step == .adjust, let image = model.capturedImage {
                let local = OnboardingSampling.orbPoint(
                    forNormalized: interim.samplePoint, imageSize: image.size, diameter: windowDiameter)
                if OnboardingSampling.isInsideOrb(local, diameter: windowDiameter) {
                    SampleMarker()
                        .offset(x: local.x - windowDiameter / 2, y: local.y - windowDiameter / 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
        }
    }

    /// How lively the bubble's idle wobble is: calm while held or tucked in the
    /// island, livelier while the camera is live, busiest while generating.
    private var orbEnergy: Double {
        switch model.step {
        case .pull, .orb: 0.25
        case .camera: 0.45
        case .adjust: 0.3
        case .generate: 1
        }
    }

    private var orbContent: OrbWindowContent {
        switch model.step {
        case .pull, .orb: .empty
        case .camera: flow.windowContent
        case .adjust: model.capturedImage.map(OrbWindowContent.photo) ?? .empty
        case .generate: .drops(interim.genColors)
        }
    }

    private var orbLabel: String {
        switch model.step {
        case .pull: "Orb at the top of the screen"
        case .orb: "Color orb"
        case .camera: model.isPhotoFrozen ? "Photo. Tap to choose a color." : "Camera preview orb"
        case .adjust: "Scanned color orb"
        case .generate: "Palette orb"
        }
    }

    /// Only the picked photo and the adjust step have a tap target on the orb.
    private func windowTap(windowDiameter: CGFloat) -> ((CGPoint) -> Void)? {
        switch model.step {
        case .camera where model.isPhotoFrozen:
            return { _ in chooseColor() }
        case .adjust:
            return { interim.resample(tap: $0, windowDiameter: windowDiameter) }
        default:
            return nil
        }
    }

    // MARK: Steps

    private func chooseColor() {
        // Phase 2 opens the expanded picker here; until then straight to adjust.
        withAnimation(.easeInOut(duration: 0.4)) { model.advance() }
    }

    private func generate() {
        guard model.selectedHex != nil else { return }
        withAnimation(.easeInOut(duration: 0.4)) { model.advance() }
        interim.startGeneration(appData: appData, reduceMotion: reduceMotion)
    }

    private func content(travels: Bool) -> OnboardingStepContent {
        switch model.step {
        case .pull:
            // Only reached when the orb does not travel from the island.
            return OnboardingStepContent(
                key: "welcome",
                title: "Welcome to Palettes",
                subtitle: "Find colors anywhere and turn them into palettes.",
                primary: .init(title: "Begin") { morph.beginFade() }
            )
        case .orb:
            return OnboardingStepContent(
                key: "orb",
                title: "Explore the colors around you",
                subtitle: "Turn anything you see into a palette.",
                primary: .init(title: "Continue") { withAnimation(.easeInOut(duration: 0.4)) { model.advance() } }
            )
        case .camera:
            return flow.stepContent(reduceMotion: reduceMotion, chooseColor: chooseColor)
        case .adjust:
            return interim.adjustContent(onGenerate: generate)
        case .generate:
            return interim.generateContent(
                appData: appData,
                retry: { interim.startGeneration(appData: appData, reduceMotion: reduceMotion) },
                open: { made in
                    guard !interim.isSaving else { return }
                    interim.isSaving = true
                    OnboardingPaletteSaver.save(made.palette, appData: appData, model: model)
                },
                skip: { model.skip() }
            )
        }
    }

    /// The text and the buttons are shown once the orb has landed. With no
    /// island to travel from, the welcome step shows straight away.
    private func controlsShown(travels: Bool) -> Bool {
        landed || (model.step == .pull && !travels)
    }

    private func stepLayer(layout: Layout, content: OnboardingStepContent) -> some View {
        let shown = controlsShown(travels: layout.island.hasMorph && !reduceMotion)
        return VStack(spacing: 0) {
            Color.clear.frame(height: layout.contentTop)
            GeometryReader { region in
                ScrollView {
                    textBlock(content)
                    .frame(maxWidth: .infinity, minHeight: region.size.height, alignment: .top)
                    .padding(.horizontal, 24)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .opacity(shown ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: shown)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar(content: content)
                .opacity(shown ? 1 : 0)
                .allowsHitTesting(shown)
                .animation(.easeOut(duration: 0.4), value: shown)
        }
        // Step copy is capped so the buttons and sliders never split words.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// Title and subtitle cross-fade with a blur when the step's copy changes.
    /// The block has a minimum height so each title starts at the same y.
    private func textBlock(_ content: OnboardingStepContent) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 20) {
                if let title = content.title {
                    OnboardingStepText(title: title, subtitle: content.subtitle)
                }
                if let body = content.body { body }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .top)
            .padding(.bottom, 16)
            .id(content.key)
            .transition(.blurFade)
        }
        .animation(.easeInOut(duration: 0.35), value: content.key)
    }

    /// Both slots keep their height so the primary button never moves between steps.
    private func actionBar(content: OnboardingStepContent) -> some View {
        VStack(spacing: 8) {
            ZStack {
                if let primary = content.primary {
                    OnboardingPrimaryButton(title: primary.title, systemImage: primary.systemImage,
                                            isEnabled: primary.isEnabled, action: primary.action)
                }
            }
            .frame(height: 54)
            ZStack {
                if let secondary = content.secondary {
                    secondary.view
                        .id(content.key)
                        .transition(.opacity)
                }
            }
            .frame(height: 44)
            .animation(.easeInOut(duration: 0.25), value: content.key)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pieces

/// The background, with the ambient field already building as the blob is pulled
/// so the clear glass has something to refract from its first moment. Once the
/// orb commits, `ambient` takes over and fades it to full.
private struct PullDrivenBackground: View {
    @ObservedObject var pull: SpringValue
    var ambient: Double

    var body: some View {
        OnboardingBackground(ambient: max(ambient, 0.7 * Easing.smoothstep(10, 100, pull.value)))
    }
}

/// "Pull down to begin", fading as soon as the pull starts.
private struct PullPrompt: View {
    @ObservedObject var pull: SpringValue

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chevron.compact.down")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Pull down to begin")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .opacity(1 - Easing.smoothstep(0, 40, pull.value))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Begins onboarding")
    }
}

private struct SampleMarker: View {
    var body: some View {
        ZStack {
            Circle().stroke(.white, lineWidth: 2).frame(width: 22, height: 22)
            Circle().stroke(.black.opacity(0.4), lineWidth: 1).frame(width: 24, height: 24)
        }
        .shadow(color: .black.opacity(0.25), radius: 2)
    }
}

#Preview {
    OnboardingView { _ in }
        .environmentObject(AppData(inMemory: true))
}
