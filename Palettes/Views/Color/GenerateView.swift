import SwiftUI
import PhotosUI
import FoundationModels

struct GenerateView: View {
    @EnvironmentObject var appData: AppData

    private enum Phase { case form, generating, result }
    @State private var phase: Phase = .form
    @Namespace private var orbNamespace

    // Form state
    @State private var paletteSize = 4
    @State private var selectedColorIDs: Set<UUID> = []
    @State private var vibeDescription = ""
    @State private var glowPhase: CGFloat = 0
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @FocusState private var vibeFocused: Bool

    // Generation state
    @State private var arrivedColors: [Color] = []
    @State private var generationTask: Task<Void, Never>?

    // Result state (editable draft)
    @State private var resultName = ""
    @State private var resultColors: [Color] = []
    @State private var resultHexes: [String] = []
    @State private var resultColorNames: [String] = []
    @State private var pendingRefinement = ""

    private let sizeOptions = [2, 4, 6, 8, 10, 12]
    private let formOrbDiameter: CGFloat = 150

    /// Iridescent tint reserved for the Apple Intelligence glyph.
    private var glowGradient: AnyShapeStyle {
        let t = Float(glowPhase)
        let d: Float = 0.18
        return AnyShapeStyle(MeshGradient(width: 3, height: 3, points: [
            SIMD2(-0.5, -0.5),
            SIMD2(0.5 + d * sin(t * .pi * 2), -0.5),
            SIMD2(1.5, -0.5),
            SIMD2(-0.5, 0.5 + d * cos(t * .pi * 2 + 1)),
            SIMD2(0.5 + d * cos(t * .pi * 2), 0.5 + d * sin(t * .pi * 2)),
            SIMD2(1.5, 0.5 - d * cos(t * .pi * 2 + 2)),
            SIMD2(-0.5, 1.5),
            SIMD2(0.5 - d * sin(t * .pi * 2 + 1.5), 1.5),
            SIMD2(1.5, 1.5)
        ], colors: [
            .yellow,  .orange, .pink,
            .orange,  .purple, .indigo,
            .pink,    .indigo, .blue
        ]))
    }

    /// The simulator can't run Apple Intelligence; show the form there so the
    /// flow stays developable. Devices still gate on real availability.
    private var isModelAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #endif
    }

    private var selectedColors: [Color] {
        appData.colors.filter { selectedColorIDs.contains($0.id) }.map { $0.color }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isModelAvailable {
                    stage
                } else if case .unavailable(let reason) = SystemLanguageModel.default.availability {
                    unavailableView(for: reason)
                }
            }
            .background {
                LiquidGradientView(
                    speed: 0.25,
                    intensity: phase == .result ? 0.22 : 0.10,
                    colors: phase == .result ? resultColors : []
                )
                .blur(radius: 60)
                .ignoresSafeArea()
            }
            .navigationTitle(phase == .form ? "Generate" : "")
            .toolbar(phase == .generating ? .hidden : .automatic, for: .navigationBar)
            .toolbar(phase == .form ? .automatic : .hidden, for: .tabBar)
            .onAppear {
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    glowPhase = 1
                }
            }
        }
    }

    // MARK: - Stage (form / generating / result)

    private var stage: some View {
        ZStack {
            formContent
                .opacity(phase == .form ? 1 : 0)
                .allowsHitTesting(phase == .form)

            if phase == .result {
                GenerationResultView(
                    name: $resultName,
                    colors: $resultColors,
                    hexCodes: $resultHexes,
                    colorNames: $resultColorNames,
                    onBack: { withAnimation(.smooth(duration: 0.5)) { phase = .form } },
                    onRegenerate: {
                        pendingRefinement = ""
                        startGeneration()
                    },
                    onDescribeChange: { change in
                        pendingRefinement = change
                        startGeneration()
                    },
                    onSave: saveResult
                )
                .environmentObject(appData)
                .transition(.blurReplace)
            }

            // While generating, the orb takes center stage as the waiting moment.
            if phase == .generating {
                generatingOrb
            }
        }
        .coordinateSpace(name: "genStage")
    }

    private var generatingOrb: some View {
        GenerationOrbView(
            colors: arrivedColors,
            promptText: generationStatusText,
            photo: selectedImage,
            expectedCount: paletteSize,
            showsProgress: true
        )
        .matchedGeometryEffect(id: "orb", in: orbNamespace)
        .frame(width: 340, height: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GenerateHeaderView(
                    showsOrb: phase == .form,
                    orbDiameter: formOrbDiameter,
                    colors: selectedColors,
                    expectedCount: paletteSize,
                    orbNamespace: orbNamespace
                )
                .zIndex(1)

                sizeSection
                colorsSection
                vibeSection
            }
            .padding(.horizontal)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Pinned above the keyboard and home indicator
        .safeAreaInset(edge: .bottom) {
            if phase == .form {
                generateBar
            }
        }
        .sensoryFeedback(.selection, trigger: selectedColorIDs)
        .sensoryFeedback(.selection, trigger: paletteSize)
        .sensoryFeedback(.impact, trigger: phase == .generating)
    }

    // MARK: - Unavailable State

    private func unavailableView(for reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        let message: String
        switch reason {
        case .deviceNotEligible:
            message = "This device doesn't support Apple Intelligence, so palettes can't be generated here."
        case .appleIntelligenceNotEnabled:
            message = "Turn on Apple Intelligence in Settings to generate palettes."
        case .modelNotReady:
            message = "The Apple Intelligence model is still getting ready. Try again in a moment."
        @unknown default:
            message = "Apple Intelligence is currently unavailable."
        }
        return ContentUnavailableView {
            Label("Apple Intelligence Unavailable", systemImage: "apple.intelligence")
        } description: {
            Text(message)
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Palette Size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("Palette Size", selection: $paletteSize) {
                ForEach(sizeOptions, id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Colors

    @ViewBuilder
    private var colorsSection: some View {
        if !appData.colors.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Start From Your Colors")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if !selectedColorIDs.isEmpty {
                        Text("· \(selectedColorIDs.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(appData.colors) { colorItem in
                            colorSwatch(colorItem)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func colorSwatch(_ colorItem: ColorViewModel) -> some View {
        let isSelected = selectedColorIDs.contains(colorItem.id)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedColorIDs.remove(colorItem.id)
                } else {
                    selectedColorIDs.insert(colorItem.id)
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(colorItem.color.gradient)
                        .frame(width: 54, height: 54)
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1)
                        }
                        .overlay {
                            if isSelected {
                                Circle()
                                    .strokeBorder(.tint, lineWidth: 3)
                                    .padding(-4)
                            }
                        }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 3, y: 3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(colorItem.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: 62)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(Text(colorItem.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Vibe

    private var vibeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Vibe")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if let image = selectedImage {
                imageChip(image)
            }

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.intelligence")
                        .font(.title3)
                        .foregroundStyle(glowGradient)

                    TextField("Warm autumn forest, neon arcade…", text: $vibeDescription)
                        .font(.body)
                        .focused($vibeFocused)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.interactive(), in: .capsule)

                imageMenuButton
            }
        }
    }

    private var hasInput: Bool {
        !selectedColorIDs.isEmpty
            || !vibeDescription.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedImage != nil
    }

    private var generationStatusText: String {
        let vibe = vibeDescription.trimmingCharacters(in: .whitespaces)
        return vibe.isEmpty ? "Generating palette…" : vibe
    }

    // MARK: - Generate Button

    private var generateBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    startGeneration()
                } label: {
                    Label("Generate Palette", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(!hasInput)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .frame(maxWidth: 640)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func imageChip(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Colors will be pulled from this photo")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedImage = nil
                    photosPickerItem = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var imageMenuButton: some View {
        Menu {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .frame(width: 44, height: 44)
                .foregroundColor(.accentColor)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .clipShape(Circle())
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage, didCapture: .constant(false), isPresented: $showCamera)
        }
    }

    // MARK: - Generation

    private func startGeneration() {
        guard generationTask == nil else { return }
        vibeFocused = false
        arrivedColors = selectedColors
        withAnimation(.smooth(duration: 0.6)) { phase = .generating }

        generationTask = Task {
            defer { generationTask = nil }
            do {
                let palette = try await performGeneration { colors in
                    arrivedColors = colors
                }
                resultName = palette.name
                resultColors = palette.colors
                resultHexes = palette.hexCodes
                resultColorNames = palette.colorNames
                // Let the last drop settle before revealing the result
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.smooth(duration: 0.7)) { phase = .result }
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
                withAnimation(.smooth(duration: 0.5)) { phase = .form }
            }
        }
    }

    private func saveResult() {
        guard resultColors.count >= 2 else { return }
        let trimmed = resultName.trimmingCharacters(in: .whitespaces)
        appData.palettes.append(PaletteViewModel(
            name: trimmed.isEmpty ? "Generated Palette" : trimmed,
            colors: resultColors,
            hexCodes: resultHexes,
            colorNames: resultColorNames
        ))

        // Add any newly generated colors to the Colors library.
        for i in resultColors.indices {
            let hex = i < resultHexes.count ? resultHexes[i] : ""
            guard !hex.isEmpty else { continue }
            let alreadyExists = appData.colors.contains { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }
            guard !alreadyExists else { continue }
            let name = i < resultColorNames.count && !resultColorNames[i].isEmpty ? resultColorNames[i] : "Color \(i + 1)"
            appData.colors.append(ColorViewModel(name: name, color: resultColors[i], HEX: hex, usedInPalette: true))
        }

        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        withAnimation(.smooth(duration: 0.5)) { phase = .form }
    }

    private func performGeneration(onColors: @escaping @MainActor ([Color]) -> Void) async throws -> PaletteViewModel {
        var baseColors: [PaletteGenerator.BaseColor] = appData.colors
            .filter { selectedColorIDs.contains($0.id) }
            .map { PaletteGenerator.BaseColor(hex: $0.HEX, name: $0.name) }

        if let image = selectedImage {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 4)
            baseColors += extracted.map { PaletteGenerator.BaseColor(hex: $0.hex, name: $0.name) }
        }

        let combinedVibe = [vibeDescription, pendingRefinement]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")

        return try await PaletteGenerator.generate(
            baseColors: baseColors,
            size: paletteSize,
            vibe: combinedVibe,
            onPartialColors: onColors
        )
    }
}

/// Orb + lensed description text, extracted so the per-frame frame reports
/// (scroll, keyboard push-up, drag) only invalidate this small subtree instead
/// of the entire GenerateView body.
private struct GenerateHeaderView: View {
    let showsOrb: Bool
    let orbDiameter: CGFloat
    let colors: [Color]
    let expectedCount: Int
    let orbNamespace: Namespace.ID

    // Lens geometry — the orb warps the text beneath it (frames in "genStage").
    @State private var orbFrame: CGRect = .zero
    @State private var descFrame: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // The orb is part of the scroll content, so it moves with the
            // view and is pushed up by the keyboard instead of overlaying.
            // When generation starts it morphs into the big centered orb.
            ZStack {
                if showsOrb {
                    GenerationOrbView(
                        colors: colors,
                        expectedCount: expectedCount,
                        coordinateSpaceName: "genStage",
                        onLiveFrameChange: { orbFrame = $0 }
                    )
                    .matchedGeometryEffect(id: "orb", in: orbNamespace)
                    .frame(width: orbDiameter, height: orbDiameter)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: orbDiameter)
            .padding(.top, 8)
            .zIndex(1)

            Text("Describe a vibe, start from your colors, or pull them from a photo — Apple Intelligence composes the palette.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("genStage"))
                } action: { descFrame = $0 }
                // Pull the orb down over this text and the clear glass lenses it.
                .distortionEffect(
                    ShaderLibrary.lensWarp(
                        .float2(Float(orbFrame.midX - descFrame.minX), Float(orbFrame.midY - descFrame.minY)),
                        .float(Float(max(orbFrame.width, orbFrame.height) / 2)),
                        .float(0.5)
                    ),
                    maxSampleOffset: CGSize(width: 90, height: 90)
                )
        }
    }
}

#Preview {
    GenerateView()
        .environmentObject(AppData())
}
