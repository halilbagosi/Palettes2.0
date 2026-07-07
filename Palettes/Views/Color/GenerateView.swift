import SwiftUI
import PhotosUI
import FoundationModels

struct GenerateView: View {
    @EnvironmentObject var appData: AppData

    @State private var paletteSize: Double = 4
    @State private var selectedColorIDs: Set<UUID> = []
    @State private var vibeDescription = ""
    @State private var glowPhase: CGFloat = 0
    @State private var bgPhase: CGFloat = 0
    @State private var colorsExpanded = false

    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false

    @State private var showGenerationExperience = false
    @State private var glowPulse = false
    @FocusState private var vibeFocused: Bool

    private var glowGradient: AnyShapeStyle {
        if #available(iOS 18.0, *) {
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
        } else {
            return AnyShapeStyle(LinearGradient(
                colors: [.yellow, .orange, .pink, .purple, .indigo, .blue],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
    }

    private let bgBlobColors: [Color] = [
        .pink, .purple, .indigo,
        Color(red: 0.6, green: 0.6, blue: 1.0),
        .blue, .cyan, .yellow, .orange
    ]

    var body: some View {
        NavigationStack {
            Group {
                switch SystemLanguageModel.default.availability {
                case .available:
                    generateContent
                case .unavailable(let reason):
                    unavailableView(for: reason)
                }
            }
            .background {
                ZStack {
                    LiquidGradientView(speed: 0.4, intensity: 0.18)
                        .blur(radius: 60)
                        .ignoresSafeArea()
                    animatedBackground
                    SparkleFieldView()
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Generate")
            .onAppear {
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    glowPhase = 1
                }
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: true)) {
                    bgPhase = 1
                }
                glowPulse = true
            }
        }
        .fullScreenCover(isPresented: $showGenerationExperience) {
            GenerationExperienceView(statusText: generationStatusText, generate: performGeneration)
                .environmentObject(appData)
        }
    }

    private var generateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                descriptionText
                    .padding(.top, 4)
                paletteSizeSection
                colorsSection
                vibeInputSection
                    .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .sensoryFeedback(.selection, trigger: selectedColorIDs)
        .sensoryFeedback(.selection, trigger: Int(paletteSize))
        .sensoryFeedback(.impact, trigger: showGenerationExperience)
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

    // MARK: - Animated Background

    private var animatedBackground: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                ForEach(Array(bgBlobColors.enumerated()), id: \.offset) { index, color in
                    let angle = Double(index) / Double(bgBlobColors.count) * .pi * 2
                    let edgeX = (1 + cos(angle)) / 2
                    let edgeY = (1 + sin(angle)) / 2
                    let drift = bgPhase * 0.12

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.12), color.opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: max(w, h) * 0.42
                            )
                        )
                        .frame(width: max(w, h) * 0.85, height: max(w, h) * 0.85)
                        .position(
                            x: w * (edgeX + drift * sin(angle + Double(index))),
                            y: h * (edgeY + drift * cos(angle + Double(index)))
                        )
                        .blendMode(.normal)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Description

    private var descriptionText: some View {
        Text("Choose or create a color to generate a complementary palette with the power of Apple Intelligence")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
    }

    // MARK: - Palette Size

    private var paletteSizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette Size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Slider(value: $paletteSize, in: 2...12, step: 2)
                    .tint(.accentColor)

                HStack {
                    ForEach([2, 4, 6, 8, 10, 12], id: \.self) { value in
                        Text("\(value)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Int(paletteSize) == value ? .primary : .tertiary)
                        if value < 12 { Spacer() }
                    }
                }

                sizeDots
                    .padding(.top, 10)
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
        .padding(.horizontal)
    }

    private var sizeDots: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<Int(paletteSize), id: \.self) { i in
                    Circle()
                        .fill(bgBlobColors[i % bgBlobColors.count].opacity(0.5))
                        .frame(width: 20, height: 20)
                        .glassEffect(.regular, in: .circle)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: Int(paletteSize))
    }

    // MARK: - Colors

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    colorsExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("Colors")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    if !selectedColorIDs.isEmpty {
                        Text("\(selectedColorIDs.count) selected")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(colorsExpanded ? 90 : 0))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if colorsExpanded {
                LazyVStack(spacing: 10) {
                    ForEach(appData.colors) { colorItem in
                        let isSelected = selectedColorIDs.contains(colorItem.id)

                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(colorItem.color.gradient)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(.white.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: colorItem.color.opacity(isSelected ? 0.7 : 0), radius: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(colorItem.name)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(colorItem.HEX)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        }
                        .padding(10)
                        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                        .scaleEffect(isSelected ? 1.02 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25)) {
                                if isSelected {
                                    selectedColorIDs.remove(colorItem.id)
                                } else {
                                    selectedColorIDs.insert(colorItem.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 6)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Vibe Input

    private var vibeInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = selectedImage {
                imageChip(image)
            }
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    vibeTextField
                    imageMenuButton
                }
            }
        }
        .padding(.horizontal)
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

    private var vibeTextField: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.intelligence")
                .font(.title3)
                .foregroundStyle(glowGradient)

            TextField("Describe palette vibe!", text: $vibeDescription)
                .font(.headline)
                .focused($vibeFocused)

            if hasInput {
                Button {
                    showGenerationExperience = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(glowGradient)
                }
                .background {
                    Circle()
                        .fill(glowGradient)
                        .blur(radius: 10)
                        .opacity(glowPulse ? 0.7 : 0.3)
                        .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasInput)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
        .background {
            Capsule()
                .fill(glowGradient)
                .blur(radius: 18)
                .opacity(vibeFocused ? 0.55 : 0.25)
                .scaleEffect(x: glowPulse ? 1.03 : 0.97, y: glowPulse ? 1.15 : 0.9)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)
                .animation(.easeInOut(duration: 0.3), value: vibeFocused)
        }
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

    private func performGeneration() async throws -> PaletteViewModel {
        var baseColors: [PaletteGenerator.BaseColor] = appData.colors
            .filter { selectedColorIDs.contains($0.id) }
            .map { PaletteGenerator.BaseColor(hex: $0.HEX, name: $0.name) }

        if let image = selectedImage {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 4)
            baseColors += extracted.map { PaletteGenerator.BaseColor(hex: $0.hex, name: $0.name) }
        }

        return try await PaletteGenerator.generate(
            baseColors: baseColors,
            size: Int(paletteSize),
            vibe: vibeDescription
        )
    }
}

#Preview {
    GenerateView()
        .environmentObject(AppData())
}
