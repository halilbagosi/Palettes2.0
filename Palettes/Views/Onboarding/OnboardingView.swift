//
//  OnboardingView.swift
//  Palettes
//
//  First-launch onboarding. A step machine over `OnboardingModel`; steps
//  after the orb are placeholders until their tasks land. The presenter
//  dismisses the cover in response to `onFinish`.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct OnboardingView: View {
    @StateObject private var model: OnboardingModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appData: AppData

    /// Rubber-banded stretch of the island blob while the user pulls down.
    @State private var pull: CGFloat = 0

    // Camera step
    @StateObject private var camera = OrbCameraController()
    @State private var pickedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var pickerError: String?
    @State private var pickerTask: Task<Void, Never>?
    @State private var advanceTask: Task<Void, Never>?
    @State private var scanCount = 0
    @State private var rippleActive = false
    @State private var rippleScale: CGFloat = 1
    @State private var rippleOpacity: Double = 0

    // Adjust step
    @State private var sampler: ImageColorExtractor.PixelSampler?
    /// Normalized image coordinate of the current sample.
    @State private var samplePoint = OnboardingSampling.center
    @State private var sampleCount = 0
    @State private var swatchRevealed = false
    @State private var dropActive = false
    @State private var dropLanded = false
    @State private var dropTask: Task<Void, Never>?

    // Generate step
    private enum GenState {
        case generating
        case ready(OnboardingPaletteMaker.Made)
        case failed
    }
    @State private var genState = GenState.generating
    @State private var genColors: [Color] = []
    @State private var genTask: Task<Void, Never>?
    @State private var isSaving = false

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
        static let swatchDiameter: CGFloat = 52
        /// Screen-space center of the selected-color swatch, the first row of
        /// the adjust captions.
        var swatchCenter: CGPoint {
            CGPoint(x: full.width / 2, y: orbTop + orbDiameter + 24 + Self.swatchDiameter / 2)
        }
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
                    .allowsHitTesting(false)
                    .overlay { ZStack { orbLayer(layout: layout, travels: travels) }.ignoresSafeArea() }

                content(layout: layout, travels: travels)

                skipButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, layout.skipTopPadding)
                    .padding(.trailing, 20)
                    .accessibilitySortPriority(1)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.step)
        .sensoryFeedback(.impact(weight: .medium), trigger: scanCount)
        .sensoryFeedback(.selection, trigger: sampleCount)
        .onChange(of: model.step) { _, step in
            if step == .camera { refreshCameraAccess() }
            if step == .adjust { beginAdjust() }
            updateCameraSession()
        }
        .onChange(of: scenePhase) { _, phase in
            // The user may have changed access in Settings while away.
            if phase == .active, model.step == .camera, model.capturedImage == nil {
                refreshCameraAccess()
            }
            updateCameraSession()
        }
        .onChange(of: model.cameraAccess) { _, _ in updateCameraSession() }
        .onChange(of: photosPickerItem) { _, item in loadPickedPhoto(item) }
        .onChange(of: camera.didFailToConfigure) { _, failed in
            // The session couldn't be set up: show the photo/sample fallback.
            if failed { model.cameraAccess = .unavailable }
        }
        .onDisappear {
            camera.stop()
            pickerTask?.cancel()
            advanceTask?.cancel()
            dropTask?.cancel()
            genTask?.cancel()
        }
    }

    // MARK: - Orb

    @ViewBuilder
    private func orbLayer(layout: Layout, travels: Bool) -> some View {
        if travels {
            let diameter = detached ? layout.orbDiameter : Self.islandDiameter + pull * 0.12
            let y = detached ? layout.orbCenter.y : Self.islandCenterY + pull
            // Stretch down the pull axis like a drop about to fall.
            let stretch = detached ? 1 : 1 + pull / 500

            OnboardingOrb(diameter: diameter, blackFill: detached ? 0 : 1, label: orbLabel,
                          colors: orbColors, backdrop: orbBackdrop, backdropID: orbBackdropID)
                // Slow black -> clear so the glass reads as filling in after it detaches.
                .animation(.easeInOut(duration: 1.4).delay(0.25), value: detached)
                .scaleEffect(x: 1 / sqrt(stretch), y: stretch, anchor: .top)
                .modifier(orbSampling(layout: layout))
                .allowsHitTesting(orbTapsEnabled)
                .position(x: layout.orbCenter.x, y: y)
        } else if detached {
            OnboardingOrb(diameter: layout.orbDiameter, blackFill: 0, label: orbLabel,
                          colors: orbColors, backdrop: orbBackdrop, backdropID: orbBackdropID)
                .modifier(orbSampling(layout: layout))
                .allowsHitTesting(orbTapsEnabled)
                .position(layout.orbCenter)
                .transition(.opacity)
        }
        if model.step == .adjust, let image = model.capturedImage {
            let local = OnboardingSampling.orbPoint(
                forNormalized: samplePoint, imageSize: image.size, diameter: layout.orbDiameter)
            if OnboardingSampling.isInsideOrb(local, diameter: layout.orbDiameter) {
                sampleMarker
                    .position(x: layout.orbCenter.x - layout.orbDiameter / 2 + local.x,
                              y: layout.orbCenter.y - layout.orbDiameter / 2 + local.y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        if dropActive {
            Circle()
                .fill(adjustedColor)
                .frame(width: Layout.swatchDiameter, height: Layout.swatchDiameter)
                .scaleEffect(dropLanded ? 1 : 0.35)
                .position(dropLanded ? layout.swatchCenter : layout.orbCenter)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        if rippleActive {
            Circle()
                .stroke(.white.opacity(0.9), lineWidth: 3)
                .frame(width: layout.orbDiameter, height: layout.orbDiameter)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .position(layout.orbCenter)
        }
    }

    private var sampleMarker: some View {
        ZStack {
            Circle().stroke(.white, lineWidth: 2).frame(width: 22, height: 22)
            Circle().stroke(.black.opacity(0.4), lineWidth: 1).frame(width: 24, height: 24)
        }
        .shadow(color: .black.opacity(0.25), radius: 2)
    }

    /// Colors shown as liquid in the orb: the palette as it blooms.
    private var orbColors: [Color] { model.step == .generate ? genColors : [] }

    /// Taps on the frozen frame re-sample; VoiceOver gets a center action.
    private func orbSampling(layout: Layout) -> OrbSamplingModifier {
        OrbSamplingModifier(
            enabled: orbTapsEnabled,
            onTap: { point in resample(tap: point, diameter: layout.orbDiameter) },
            onCenter: { resample(to: OnboardingSampling.center) }
        )
    }

    /// Only the adjust step has a tap target on the orb; the rest let
    /// touches fall through to the content underneath.
    private var orbTapsEnabled: Bool { model.step == .adjust }

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
                // Not hittable, so a drag starting on the caption still reaches
                // the pull gesture underneath; Begin stays tappable.
                VStack(spacing: 10) {
                    Image(systemName: "chevron.compact.down")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Pull down to begin")
                        .font(.title3.weight(.medium))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .allowsHitTesting(false)

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
            case .camera:
                cameraCaptions
            case .adjust:
                adjustCaptions
            case .generate:
                generateCaptions
            case .pull:
                EmptyView()
            }
        }
    }

    // MARK: - Camera step

    /// Camera preview, or the chosen/sample still when the camera isn't usable.
    private var showsStill: Bool { model.cameraUIState == .photoFallback || pickedImage != nil }
    private var stillImage: UIImage { pickedImage ?? OnboardingSampleImage.shared }

    private var orbBackdrop: AnyView? {
        // The generate step shows the chosen color in an empty orb.
        if model.step == .generate { return nil }
        if let frozen = model.capturedImage {
            return AnyView(Image(uiImage: frozen).resizable().scaledToFill())
        }
        guard model.step == .camera else { return nil }
        if showsStill {
            return AnyView(Image(uiImage: stillImage).resizable().scaledToFill())
        }
        if model.cameraUIState == .live {
            return AnyView(OrbCameraPreview(controller: camera, device: camera.device))
        }
        return nil
    }

    /// Changes whenever the backdrop swaps, so the orb cross-fades.
    private var orbBackdropID: Int {
        if model.step == .generate { return 5 }
        if model.capturedImage != nil { return 3 }
        guard model.step == .camera else { return 0 }
        if showsStill { return pickedImage == nil ? 2 : 4 }
        return model.cameraUIState == .live ? 1 : 0
    }

    @ViewBuilder
    private var cameraCaptions: some View {
        switch model.cameraUIState {
        case .needsPermission where pickedImage == nil:
            Text("Palettes uses your camera to find a color. Nothing is saved or uploaded.")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // Not worded like the system alert's buttons (App Review 5.1.1(iv)).
            Button("Continue") { requestCameraAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        default:
            if model.cameraUIState == .photoFallback && pickedImage == nil {
                Text(fallbackMessage)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if camera.isInterrupted && model.cameraUIState == .live {
                Text("Camera paused while another app is using it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                scan()
            } label: {
                Label("Scan", systemImage: "viewfinder")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
            }
            .glassCapsuleButton()
            .disabled(isScanning || camera.isInterrupted)
            .accessibilityHint("Captures the color in the orb")
            if model.cameraAccess == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.body.weight(.medium))
            }
        }
        PhotosPicker(selection: $photosPickerItem, matching: .images) {
            Text("Use a photo instead")
                .font(.body.weight(.medium))
        }
        .disabled(isScanning)
        if let pickerError {
            Text(pickerError)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fallbackMessage: String {
        switch model.cameraAccess {
        case .denied, .restricted: "Camera access is off. Scan the sample, or pick a photo."
        default:
            camera.didFailToConfigure
                ? "Camera isn't available right now. Scan the sample, or pick a photo."
                : "No camera here. Scan the sample, or pick a photo."
        }
    }

    private func refreshCameraAccess() {
        // Start from the status alone so granted users never see the pre-prompt flash.
        model.cameraAccess = .quick()
        Task { model.cameraAccess = await .current() }
    }

    private func requestCameraAccess() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            model.cameraAccess = .quick()
            model.cameraAccess = await .current()
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        pickerTask?.cancel()
        pickerError = nil
        pickerTask = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let image: UIImage? = if let data {
                await Task.detached { OnboardingImageLoader.downscaled(from: data) }.value
            } else {
                nil
            }
            guard !Task.isCancelled else { return }
            if let image {
                pickedImage = image
                updateCameraSession()
            } else {
                pickerError = "Couldn't load that photo. Try another."
            }
            // Lets the same photo be picked again.
            photosPickerItem = nil
        }
    }

    /// The session only runs while the camera step is visible, the app is
    /// active, access is granted, and nothing is frozen or picked.
    private func updateCameraSession() {
        let wanted = model.step == .camera
            && scenePhase == .active
            && model.cameraUIState == .live
            && model.capturedImage == nil
            && pickedImage == nil
        if wanted { camera.start() } else { camera.stop() }
    }

    private func scan() {
        guard !isScanning else { return }
        isScanning = true
        advanceTask = Task {
            let image: UIImage?
            if showsStill {
                image = stillImage
            } else if let data = await camera.capturePhoto() {
                image = await Task.detached { OnboardingImageLoader.downscaled(from: data) }.value
            } else {
                image = nil
            }
            guard !Task.isCancelled, let image else {
                isScanning = false
                return
            }
            scanCount += 1
            withAnimation(.easeInOut(duration: 0.4)) { model.capturedImage = image }
            updateCameraSession()
            playRipple()
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.0))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { model.advance() }
            isScanning = false
        }
    }

    /// A ring expanding from the orb's edge; Reduce Motion gets the image
    /// cross-fade alone.
    private func playRipple() {
        guard !reduceMotion else { return }
        rippleScale = 1
        rippleOpacity = 1
        rippleActive = true
        withAnimation(.easeOut(duration: 0.9)) {
            rippleScale = 1.4
            rippleOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(1))
            rippleActive = false
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

// MARK: - Adjust and generate steps

extension OnboardingView {
    private var adjustedColor: Color {
        guard let rgb = model.adjustedRGB else { return .gray }
        return ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)
    }

    private var adjustedName: String {
        guard let hex = model.selectedHex else { return "" }
        return ColorNamer.name(forHex: String(hex.dropFirst()))
    }

    /// Samples the center of the frozen frame and drops the color out of the
    /// orb into the swatch. Reduce Motion just fades the swatch in.
    fileprivate func beginAdjust() {
        guard let image = model.capturedImage else { return }
        sampler = ImageColorExtractor.PixelSampler(image: image)
        model.brightness = 0.5
        model.saturation = 0.5
        samplePoint = OnboardingSampling.center
        model.scannedRGB = rgb(at: samplePoint, in: image)
        swatchRevealed = false
        dropTask?.cancel()
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.4)) { swatchRevealed = true }
            return
        }
        dropLanded = false
        dropActive = true
        dropTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { dropLanded = true }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { swatchRevealed = true }
            dropActive = false
        }
    }

    private func rgb(at point: CGPoint, in image: UIImage) -> (r: Double, g: Double, b: Double) {
        sampler?.color(at: point, radius: 2) ?? ImageColorExtractor.sampleColor(from: image, at: point, radius: 2)
    }

    fileprivate func resample(tap: CGPoint, diameter: CGFloat) {
        guard let image = model.capturedImage,
              let normalized = OnboardingSampling.normalizedPoint(
                forTap: tap, imageSize: image.size, diameter: diameter) else { return }
        resample(to: normalized)
    }

    fileprivate func resample(to normalized: CGPoint) {
        guard model.step == .adjust, let image = model.capturedImage else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            samplePoint = normalized
            model.scannedRGB = rgb(at: normalized, in: image)
            swatchRevealed = true
        }
        sampleCount += 1
        UIAccessibility.post(notification: .announcement, argument: "Selected \(adjustedName)")
    }

    private func percentLabel(_ value: Double, neutral: String) -> String {
        let percent = Int(((value - 0.5) * 200).rounded())
        return percent == 0 ? neutral : String(format: "%+d%%", percent)
    }

    @ViewBuilder
    var adjustCaptions: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(adjustedColor)
                .frame(width: Layout.swatchDiameter, height: Layout.swatchDiameter)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                .opacity(swatchRevealed ? 1 : 0)
            Text(adjustedName)
                .font(.headline)
                .opacity(swatchRevealed ? 1 : 0)
            Text(model.selectedHex ?? "")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .opacity(swatchRevealed ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected color")
        .accessibilityValue("\(adjustedName), \(model.selectedHex ?? "")")
        Text("Tap the photo to pick a different spot.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        VStack(spacing: 14) {
            AdjustmentSlider(
                title: "Brightness",
                valueLabel: percentLabel(model.brightness, neutral: "Neutral"),
                leftLabel: "Darker", rightLabel: "Brighter",
                value: $model.brightness
            )
            AdjustmentSlider(
                title: "Saturation",
                valueLabel: percentLabel(model.saturation, neutral: "Neutral"),
                leftLabel: "Muted", rightLabel: "Vivid",
                value: $model.saturation
            )
        }
        .frame(maxWidth: 420)
        Button {
            generate()
        } label: {
            Label("Generate palette", systemImage: "sparkles")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 12)
        }
        .glassCapsuleButton()
        .accessibilityHint("Builds a palette from this color")
    }

    private func generate() {
        guard model.selectedHex != nil else { return }
        dropTask?.cancel()
        withAnimation(.easeInOut(duration: 0.4)) {
            dropActive = false
            model.advance()
        }
        startGeneration()
    }

    private func startGeneration() {
        guard let hex = model.selectedHex else { return }
        genTask?.cancel()
        // The chosen color is already in the orb; the rest bloom from it.
        genColors = [adjustedColor]
        withAnimation(.easeInOut(duration: 0.3)) { genState = .generating }
        let names = appData.palettes.map(\.name)
        let delay: Duration = reduceMotion ? .zero : .milliseconds(650)
        genTask = Task {
            do {
                let made = try await OnboardingPaletteMaker.make(
                    anchorHex: hex, existingNames: names, revealDelay: delay
                ) { colors in genColors = colors }
                guard !Task.isCancelled else { return }
                genColors = made.palette.colors
                withAnimation(.easeInOut(duration: 0.4)) { genState = .ready(made) }
                UIAccessibility.post(notification: .announcement,
                                     argument: "Palette ready: \(made.palette.name)")
            } catch is CancellationError {
                // Skipped or left the screen.
            } catch {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.3)) { genState = .failed }
            }
        }
    }

    @ViewBuilder
    var generateCaptions: some View {
        switch genState {
        case .generating:
            Text("Mixing your palette…")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .transition(.opacity)
                .accessibilityLabel("Generating your palette")
        case .ready(let made):
            VStack(spacing: 20) {
                OnboardingPaletteName(name: made.palette.name, usesGradient: made.usedAI)
                HStack(spacing: 0) {
                    ForEach(made.palette.paletteColors) { color in
                        Rectangle().fill(color.color)
                    }
                }
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.25), lineWidth: 1))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Palette colors")
                .accessibilityValue(made.palette.paletteColors.map { "\($0.name), \($0.hex)" }.joined(separator: "; "))
                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    OnboardingPaletteSaver.save(made.palette, appData: appData, model: model)
                } label: {
                    Label("See my palette", systemImage: "arrow.right")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 12)
                }
                .glassCapsuleButton()
                .disabled(isSaving)
            }
            .frame(maxWidth: 420)
            .transition(.opacity)
        case .failed:
            Text("Couldn't make a palette just now.")
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                startGeneration()
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 12)
            }
            .glassCapsuleButton()
            Button("Skip for now") { model.skip() }
                .font(.body.weight(.medium))
        }
    }
}

/// Taps on the orb re-sample the frozen frame; VoiceOver users get an
/// action to pick the center instead.
private struct OrbSamplingModifier: ViewModifier {
    let enabled: Bool
    let onTap: (CGPoint) -> Void
    let onCenter: () -> Void

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 1, coordinateSpace: .local) { if enabled { onTap($0) } }
            .accessibilityAddTraits(enabled ? .isButton : [])
            .accessibilityHint(enabled ? "Double tap to pick the center color, or tap the photo to pick a spot." : "")
            .accessibilityAction(named: "Pick center color") { if enabled { onCenter() } }
    }
}

#Preview {
    OnboardingView { _ in }
        .environmentObject(AppData(inMemory: true))
}
