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

    /// Rubber-banded stretch of the island blob while the user pulls down.
    @State private var pull: CGFloat = 0

    // Camera step
    @State private var camera = OrbCameraController()
    @State private var sampleImage = OnboardingSampleImage.make()
    @State private var pickedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isScanning = false
    @State private var scanCount = 0
    @State private var rippleActive = false
    @State private var rippleScale: CGFloat = 1
    @State private var rippleOpacity: Double = 0

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
        .onChange(of: model.step) { _, step in
            if step == .camera { model.cameraAccess = .current() }
            updateCameraSession()
        }
        .onChange(of: scenePhase) { _, phase in
            // The user may have changed access in Settings while away.
            if phase == .active, model.step == .camera, model.capturedImage == nil {
                model.cameraAccess = .current()
            }
            updateCameraSession()
        }
        .onChange(of: model.cameraAccess) { _, _ in updateCameraSession() }
        .onChange(of: photosPickerItem) { _, item in loadPickedPhoto(item) }
        .onDisappear { camera.stop() }
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
                          backdrop: orbBackdrop, backdropID: orbBackdropID)
                // Slow black -> clear so the glass reads as filling in after it detaches.
                .animation(.easeInOut(duration: 1.4).delay(0.25), value: detached)
                .scaleEffect(x: 1 / sqrt(stretch), y: stretch, anchor: .top)
                .allowsHitTesting(orbTapsEnabled)
                .position(x: layout.orbCenter.x, y: y)
        } else if detached {
            OnboardingOrb(diameter: layout.orbDiameter, blackFill: 0, label: orbLabel,
                          backdrop: orbBackdrop, backdropID: orbBackdropID)
                .allowsHitTesting(orbTapsEnabled)
                .position(layout.orbCenter)
                .transition(.opacity)
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

    /// Only steps with a tap target on the orb receive touches; the rest let
    /// them fall through to the content underneath. (Task 4 re-samples on tap.)
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
            case .generate:
                // Placeholder: Task 4 finishes with `.completed(paletteID:)`.
                Text("Step \(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("Finish") { model.skip() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            default:
                // Adjust lands in Task 4.
                Text("Step \(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                continueButton
            }
        }
    }

    // MARK: - Camera step

    /// Camera preview, or the chosen/sample still when the camera isn't usable.
    private var showsStill: Bool { model.cameraUIState == .photoFallback || pickedImage != nil }
    private var stillImage: UIImage { pickedImage ?? sampleImage }

    private var orbBackdrop: AnyView? {
        if let frozen = model.capturedImage {
            return AnyView(Image(uiImage: frozen).resizable().scaledToFill())
        }
        guard model.step == .camera else { return nil }
        if showsStill {
            return AnyView(Image(uiImage: stillImage).resizable().scaledToFill())
        }
        if model.cameraUIState == .live {
            return AnyView(OrbCameraPreview(session: camera.session))
        }
        return nil
    }

    /// Changes whenever the backdrop swaps, so the orb cross-fades.
    private var orbBackdropID: Int {
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
            Button("Allow Camera") { requestCameraAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        default:
            if model.cameraUIState == .photoFallback && pickedImage == nil {
                Text(fallbackMessage)
                    .font(.title3.weight(.medium))
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
            .disabled(isScanning)
            .accessibilityHint("Captures the color in the orb")
        }
        PhotosPicker(selection: $photosPickerItem, matching: .images) {
            Text("Use a photo instead")
                .font(.body.weight(.medium))
        }
        .disabled(isScanning)
    }

    private var fallbackMessage: String {
        switch model.cameraAccess {
        case .denied, .restricted: "Camera access is off. Scan the sample, or pick a photo."
        default: "No camera here. Scan the sample, or pick a photo."
        }
    }

    private func requestCameraAccess() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .video)
            model.cameraAccess = .current()
        }
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                pickedImage = image
                updateCameraSession()
            }
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
        Task {
            let image = showsStill ? stillImage : await camera.capturePhoto()
            guard let image else {
                isScanning = false
                return
            }
            scanCount += 1
            withAnimation(.easeInOut(duration: 0.4)) { model.capturedImage = image }
            updateCameraSession()
            playRipple()
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.6 : 1.0))
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

#Preview {
    OnboardingView { _ in }
}
