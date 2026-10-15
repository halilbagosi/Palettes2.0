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
    /// The frozen photo is open full screen to pick a color.
    @State private var showsPhotoPicker = false

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
        /// The safe area's insets from `full`.
        let insets: EdgeInsets
        let island: IslandGeometry
        let compact: Bool
        /// The step needs more room below the orb (the sliders): the orb rises.
        var roomy = false
        /// iPhone Duo half open, in `full`'s coordinates. The orb takes one
        /// side of the crease and the text and buttons the other.
        var fold: Fold? = nil

        var topInset: CGFloat { insets.top }

        /// Bars on one side only (iPhone Duo puts the status bar and controls
        /// along an edge): the safe area is off centre.
        var hasSideControls: Bool { abs(insets.leading - insets.trailing) > 8 }

        /// iPhone Duo's outer display: a small screen with its bars on one
        /// side. There the orb centres on the safe area, with the text, and is
        /// a little smaller. Bigger screens keep everything centred on the
        /// screen itself.
        var centersOnSafeArea: Bool {
            hasSideControls && min(full.width, full.height) < 600
        }

        /// The orb's and the text's shared centre line.
        var centerX: CGFloat {
            guard centersOnSafeArea else { return full.width / 2 }
            return insets.leading + (full.width - insets.leading - insets.trailing) / 2
        }

        /// Padding that moves the text's centre from the safe area's to the
        /// screen's, matching the orb, when bars sit on one side.
        var textBalance: EdgeInsets {
            guard !centersOnSafeArea else { return EdgeInsets() }
            return EdgeInsets(top: 0, leading: max(0, insets.trailing - insets.leading),
                              bottom: 0, trailing: max(0, insets.leading - insets.trailing))
        }

        private var baseOrbDiameter: CGFloat {
            if compact { return min(240, full.width * 0.62) }
            let phone = min(310, full.width * 0.76)
            // iPad and iPhone Duo: grows with the screen, leaving room under it for the text.
            guard full.width >= 600 else { return phone }
            let shortSide = min(full.width, full.height)
            return max(phone, min(460, shortSide * 0.5, full.height * 0.4))
        }

        /// A large screen in landscape (iPhone Duo's inner display fully open,
        /// iPad): short for its width, so the orb gives way to the copy.
        private var isWideLandscape: Bool { !compact && full.width > full.height }

        /// Room the step needs under the orb: the gap, the copy (title,
        /// subtitle and the step's body, like the generate step's swatches),
        /// the pinned buttons and the bottom inset.
        private var heightBelowOrb: CGFloat { 28 + 240 + 114 + insets.bottom }

        /// The lowest the orb's centre may sit with everything under it fitting.
        private var lowestCenterY: CGFloat { full.height - heightBelowOrb - orbDiameter / 2 }

        var orbDiameter: CGFloat {
            var base = baseOrbDiameter * (centersOnSafeArea ? 0.85 : 1)
            if fold == nil, isWideLandscape {
                base = max(140, min(base, full.height - skipBottom - 12 - heightBelowOrb))
            }
            guard let fold else { return base }
            if fold.isVertical {
                let side = fold.frame.minX - insets.leading
                let height = full.height - insets.top - insets.bottom
                return max(120, min(base, side * 0.7, height * 0.62))
            }
            let above = fold.frame.minY - skipBottom - 12
            return max(120, min(base, above * 0.78, full.width * 0.6))
        }
        /// Skip's pill: 6 below the top safe area, 30 tall.
        var skipBottom: CGFloat { topInset + 6 + 30 }
        var restCenter: CGPoint {
            if let fold {
                if fold.isVertical {
                    // Centred in the side before the crease; the text takes the other.
                    let x = (insets.leading + fold.frame.minX) / 2
                    let y = insets.top + (full.height - insets.top - insets.bottom) / 2
                    return CGPoint(x: x, y: y)
                }
                // Centred above the crease, below Skip.
                return CGPoint(x: centerX, y: (skipBottom + 12 + fold.frame.minY) / 2)
            }
            // 38% of the height; short screens keep the orb higher to leave room for the text.
            let highest = skipBottom + 12 + orbDiameter / 2
            var y = max(full.height * (full.height < 700 ? 0.34 : 0.38), highest)
            // Wide and short: high enough that the copy clears the buttons.
            if isWideLandscape { y = max(highest, min(y, lowestCenterY)) }
            // Roomy: up to 64 pt higher, stopping short of Skip.
            return CGPoint(x: centerX, y: roomy ? max(highest, y - 64) : y)
        }
        /// Safe-area-space top of the text region, under the orb (or, folded
        /// horizontally, under the crease).
        var contentTop: CGFloat {
            if let fold, !fold.isVertical { return fold.frame.maxY + 16 - topInset }
            return restCenter.y + orbDiameter / 2 + 28 - topInset
        }
        /// Folded vertically, the width the text and buttons keep to: the
        /// side after the crease, up to the safe area's trailing edge.
        var trailingColumnWidth: CGFloat? {
            guard let fold, fold.isVertical else { return nil }
            return max(0, full.width - insets.trailing - fold.frame.maxX)
        }
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
                insets: insets,
                island: .make(topInset: insets.top, screenSize: full),
                compact: dynamicTypeSize.isAccessibilitySize || full.height < 700,
                // The generate step's name and swatches need the room too; the
                // orb stays where adjust left it.
                roomy: model.step == .adjust || model.step == .generate,
                fold: geo.activeFold?.dividing(geo.size)?.offsetBy(dx: insets.leading, dy: insets.top)
            )
            // Reduce Motion fades the orb in at rest.
            let travels = layout.island.hasMorph && !reduceMotion
            let _ = morph.placement = layout.placement

            ZStack {
                PullDrivenBackground(pull: morph.pull, ambient: ambient)

                // Fixed light on the surface under where the orb rests. It
                // gathers in as the orb settles, together with its shadow.
                SettleDrivenStageGlow(controller: morph, diameter: layout.orbDiameter)
                    .position(layout.restCenter)
                    .ignoresSafeArea()

                if model.step == .pull && travels {
                    pullGestureLayer
                    PullPrompt(pull: morph.pull)
                        .position(layout.restCenter)
                        .transition(.opacity)
                        .accessibilityAction { morph.useFadeMode(); morph.beginFade() }
                }

                if !(model.step == .pull && travels) {
                    stepLayer(layout: layout, content: content(travels: travels))
                }

                // Above the text and buttons: pulled over them, the glass bends
                // them. It only takes touches on the drop itself.
                IslandMorphStage(controller: morph) { diameter, settle in
                    orb(diameter: diameter, settle: settle, layout: layout)
                }

                OnboardingSkipButton { model.skip() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 6 - 7)
                    .padding(.trailing, 20 - 7)
                    // Always reachable, except while the orb is travelling to its place.
                    .opacity(skipVisible ? 1 : 0)
                    .allowsHitTesting(skipVisible)
                    .animation(.easeOut(duration: 0.3), value: skipVisible)

                if showsPhotoPicker, let image = model.capturedImage {
                    PhotoColorPickerView(
                        image: image,
                        initialRGB: model.step == .adjust ? model.scannedRGB : interim.suggestedRGB(),
                        adaptiveStage: true,
                        onClose: { withAnimation(.easeInOut(duration: 0.35)) { showsPhotoPicker = false } },
                        onUse: { _ in },
                        onUseSample: { rgb, _ in
                            if model.step == .camera {
                                interim.usePicked(rgb: rgb)
                                withAnimation(.easeInOut(duration: 0.4)) { model.advance() }
                            } else {
                                withAnimation(.easeInOut(duration: 0.4)) { interim.applyPicked(rgb: rgb) }
                            }
                        }
                    )
                    .transition(BlurFade(radius: 10, rise: 0).combined(with: ScaleTransition(0.94)))
                    .zIndex(10)
                }
            }
            .animation(.easeOut(duration: 0.3), value: model.step == .pull)
            .onChange(of: travels, initial: true) { _, travels in
                if travels { morph.useMorphMode() } else { morph.useFadeMode() }
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
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged {
                        morph.dragChanged(translation: $0.translation, location: $0.location,
                                          time: $0.time.timeIntervalSinceReferenceDate)
                    }
                    .onEnded { morph.dragEnded(time: $0.time.timeIntervalSinceReferenceDate) }
            )
    }

    // MARK: Orb

    private func orb(diameter: CGFloat, settle: Double, layout: Layout) -> some View {
        OnboardingOrbView(
                diameter: diameter,
                content: orbContent,
                label: orbLabel,
                onWindowTap: windowTap,
                flash: flow.flash,
                windowScale: flow.windowScale,
                // Livelier while the camera is live or a palette is generating.
                energy: orbEnergy,
                kick: flow.scanCount,
                glow: settle
            )
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
        case .adjust: .color(interim.adjustedColor)
        case .generate: .drops(interim.genColors)
        }
    }

    private var orbLabel: String {
        switch model.step {
        case .pull: "Orb at the top of the screen"
        case .orb: "Color orb"
        case .camera: model.isPhotoFrozen
            ? (Self.picksColor ? "Photo. Tap to choose a color." : "Photo")
            : "Camera preview orb"
        case .adjust: "Picked color orb. Tap to pick again."
        case .generate: "Palette orb"
        }
    }

    /// The picked photo and the picked color open the color picker.
    private var windowTap: ((CGPoint) -> Void)? {
        switch model.step {
        case .camera where model.isPhotoFrozen:
            guard Self.picksColor else { return nil }
            return { _ in chooseColor() }
        case .adjust:
            return { _ in chooseColor() }
        default:
            return nil
        }
    }

    // MARK: Steps

    /// Opens the frozen photo full screen with the color picker.
    private func chooseColor() {
        withAnimation(.easeInOut(duration: 0.35)) { showsPhotoPicker = true }
    }

    /// With Apple Intelligence the user picks a color and a palette is
    /// generated around it. Without it, the photo's colors are the palette.
    private static var picksColor: Bool { OnboardingPaletteMaker.usesAI }

    private func makeFromPhoto() {
        withAnimation(.easeInOut(duration: 0.4)) { model.skipToGenerate() }
        interim.startFromPhoto(appData: appData, reduceMotion: reduceMotion)
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
                eyebrow: .init(title: "Welcome", systemImage: "hand.wave.fill"),
                title: "Welcome to Palettes",
                subtitle: "Catch the colors you love and turn them into palettes.",
                primary: .init(title: "Get started") { morph.beginFade() }
            )
        case .orb:
            return OnboardingStepContent(
                key: "orb",
                eyebrow: .init(title: "Hello there", systemImage: "sparkles"),
                title: "Colors are everywhere",
                subtitle: "Find one that catches your eye, and we\u{2019}ll build a whole palette around it.",
                primary: .init(title: "Let\u{2019}s go") { withAnimation(.easeInOut(duration: 0.4)) { model.advance() } }
            )
        case .camera:
            let makePalette: (() -> Void)? = Self.picksColor ? nil : { makeFromPhoto() }
            return flow.stepContent(reduceMotion: reduceMotion, chooseColor: chooseColor,
                                    makePalette: makePalette)
        case .adjust:
            return interim.adjustContent(onGenerate: generate, onRepick: chooseColor)
        case .generate:
            return interim.generateContent(
                appData: appData,
                retry: { interim.restart(appData: appData, reduceMotion: reduceMotion) },
                open: { made in
                    guard !interim.isSaving else { return }
                    interim.isSaving = true
                    OnboardingPaletteSaver.save(made.palette, anchorHex: made.anchorHex,
                                                appData: appData, model: model)
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

    @ViewBuilder
    private func stepLayer(layout: Layout, content: OnboardingStepContent) -> some View {
        let shown = controlsShown(travels: layout.island.hasMorph && !reduceMotion)
        if let columnWidth = layout.trailingColumnWidth {
            sideStepLayer(columnWidth: columnWidth, content: content, shown: shown)
        } else {
            stackedStepLayer(layout: layout, content: content, shown: shown)
        }
    }

    /// iPhone Duo half open in landscape: the text and buttons, centred
    /// together, in the side after the crease; the orb has the side before it.
    private func sideStepLayer(columnWidth: CGFloat, content: OnboardingStepContent, shown: Bool) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            GeometryReader { region in
                ScrollView {
                    VStack(spacing: 0) {
                        textBlock(content)
                            .padding(.horizontal, 24)
                        actionBar(content: content)
                    }
                    .frame(maxWidth: .infinity, minHeight: region.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: columnWidth)
        }
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .animation(.easeOut(duration: 0.4), value: shown)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// The orb above, the text under it and the buttons pinned at the bottom.
    private func stackedStepLayer(layout: Layout, content: OnboardingStepContent, shown: Bool) -> some View {
        VStack(spacing: 0) {
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
        // Centred on the same line as the orb.
        .padding(layout.textBalance)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar(content: content)
                .padding(layout.textBalance)
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
                VStack(spacing: 14) {
                    if let eyebrow = content.eyebrow {
                        OnboardingEyebrow(title: eyebrow.title, systemImage: eyebrow.systemImage)
                    }
                    if let title = content.title {
                        OnboardingStepText(title: title, subtitle: content.subtitle)
                    }
                }
                if let body = content.body { body }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .top)
            // Clear air above the pinned buttons, even when the content scrolls.
            .padding(.bottom, 28)
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
                        .transition(BlurFade(radius: 8, rise: 10))
                }
            }
            .frame(height: 54)
            .animation(.easeInOut(duration: 0.45), value: content.primary == nil)
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

/// The stage light under the orb's resting place, following the orb's settle
/// so light and shadow arrive as one. Observes the spring itself so only this
/// layer re-renders per frame.
private struct SettleDrivenStageGlow: View {
    @ObservedObject var controller: IslandMorphController
    @ObservedObject var detach: SpringValue
    var diameter: CGFloat

    init(controller: IslandMorphController, diameter: CGFloat) {
        self.controller = controller
        self.detach = controller.detach
        self.diameter = diameter
    }

    var body: some View {
        let settle = controller.settle
        BubbleStageGlow(diameter: diameter, lightHalo: true)
            // Starts a little wide and contracts to rest, like light pooling.
            .scaleEffect(1 + 0.15 * (1 - settle))
            .opacity(settle)
    }
}

/// "Pull down to begin": a cascade of chevrons pulsing downward, the copy
/// drifting gently, all fading as soon as the pull starts.
private struct PullPrompt: View {
    @ObservedObject var pull: SpringValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            VStack(spacing: 18) {
                VStack(spacing: -7) {
                    ForEach(0..<3, id: \.self) { index in
                        let phase = (t * 0.9 - Double(index) * 0.2).truncatingRemainder(dividingBy: 1)
                        let wave = pow(sin(.pi * (phase < 0 ? phase + 1 : phase)), 2)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.primary)
                            .opacity(reduceMotion ? 0.5 : 0.12 + 0.78 * wave)
                            .offset(y: reduceMotion ? 0 : CGFloat(wave) * 5)
                    }
                }
                VStack(spacing: 6) {
                    Text("Pull down to begin")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("Drag from the top of the screen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .offset(y: reduceMotion ? 0 : CGFloat(sin(t * 1.6)) * 3)
            }
        }
        .padding(.horizontal, 32)
        // The cue follows the pull a little, then is gone.
        .offset(y: CGFloat(Easing.smoothstep(0, 60, pull.value)) * 14)
        .opacity(1 - Easing.smoothstep(0, 40, pull.value))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Begins onboarding")
    }
}

#Preview {
    OnboardingView { _ in }
        .environmentObject(AppData(inMemory: true))
}
