import SwiftUI
import PhotosUI
import FoundationModels
import Foundation

@available(iOS 26.0, *)
struct GenerateView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private enum Phase { case form, generating, result }
    @State private var phase: Phase = .form
    @Namespace private var orbNamespace

    // Form state
    @State private var paletteSize = 4
    @State private var colorsFadeLeading = false
    @State private var colorsFadeTrailing = true
    @State private var selectedColorIDs: Set<UUID> = []
    @State private var scheme: HarmonyScheme = .auto
    @State private var vibeDescription = ""
    @State private var glowPhase: CGFloat = 0
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @FocusState private var vibeFocused: Bool
    /// The stage's size, for its orientation and the generating orb's size.
    @State private var stageSize: CGSize = .zero
    /// iPhone Duo half open (see `FoldCompat`): the orb takes the side before
    /// the crease and the controls the side after it.
    @State private var fold: Fold?
    /// The side insets for the generating orb and the result. Measured here,
    /// where they've settled long before either appears, and held while
    /// they're up: the bars change under them (the tab bar hides, the
    /// result's toolbar arrives in the side bar), and following that would
    /// make them jump.
    @State private var sideInsets = SideInsets()
    @State private var liveSideInsets = SideInsets()

    // Generation state
    @State private var arrivedColors: [Color] = []
    @State private var generationTask: Task<Void, Never>?

    // Result state (editable draft). A single `PaletteColor` array is the
    // sole source of truth here — no parallel colors/hexCodes/colorNames
    // arrays to keep aligned by index, and roles ride along for free.
    @State private var resultName = ""
    @State private var resultPaletteColors: [PaletteColor] = []
    @State private var pendingRefinement = ""
    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false
    @State private var duplicateOfName = ""

    private let sizeOptions = [2, 4, 6, 8, 10, 12]
    private let formOrbDiameter: CGFloat = 156

    /// Iridescent tint reserved for the Apple Intelligence glyph.
    private var glowGradient: AnyShapeStyle {
        GeneratedGradient.style(phase: glowPhase)
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

    /// The held side insets; balanced in landscape, where the bars sit along
    /// one side, so the view centres on the screen.
    private var heldSideInsets: SideInsets {
        isPortrait ? sideInsets : sideInsets.balanced
    }

    /// The stage is taller than it is wide (or hasn't been measured yet).
    private var isPortrait: Bool {
        stageSize == .zero || stageSize.height > stageSize.width
    }

    /// A wide, short stage (an iPhone, or iPhone Duo's outer display, in
    /// landscape), where `splitForm` packs its controls tighter.
    private var isWideAndShort: Bool {
        !isPortrait && (verticalSizeClass == .compact || stageSize.height < 500)
    }

    /// iPad and iPhone Duo in portrait at full size: every color is shown in
    /// a grid that scrolls under the options (`gridForm`), instead of a strip.
    private var showsColorGrid: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular && isPortrait
    }

    private var selectedColors: [Color] {
        appData.colors.filter { selectedColorIDs.contains($0.id) }.map { $0.color }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isModelAvailable {
                    stage
                        .featureIntro(.generate)
                } else if case .unavailable(let reason) = SystemLanguageModel.default.availability {
                    unavailableView(for: reason)
                }
            }
            .background {
                LiquidGradientView(
                    speed: 0.25,
                    intensity: phase == .result ? 0.22 : 0.10,
                    colors: phase == .result ? resultPaletteColors.map(\.color) : []
                )
                .blur(radius: 60)
                .ignoresSafeArea()
            }
            .navigationTitle(phase == .form ? "Generate" : "")
            // Folded, the orb needs the height a large title would take.
            .navigationBarTitleDisplayMode(fold == nil ? .automatic : .inline)
            // Kept in landscape: bringing the bar back for the result moved the
            // side insets a moment after the result appeared, so it jumped over.
            .toolbar(phase == .generating && isPortrait ? .hidden : .automatic, for: .navigationBar)
            .toolbar(phase == .form ? .automatic : .hidden, for: .tabBar)
            .onAppear {
                withAnimation(.easeInOut(duration: GeneratedGradient.cycleDuration).repeatForever(autoreverses: true)) {
                    glowPhase = 1
                }
                consumePendingColor()
            }
            .onChange(of: appData.pendingGenerateColorID) {
                consumePendingColor()
            }
        }
    }

    // MARK: - Stage (form / generating / result)

    private var stage: some View {
        stageContent
            .onGeometryChange(for: CGSize.self) { $0.size } action: { stageSize = $0 }
            .onSideInsetsChange { insets in
                liveSideInsets = insets
                if phase == .form { sideInsets = insets }
            }
            // Turning the device is a new layout anyway: take the new inset,
            // once the bars have settled into their new places.
            .onChange(of: isPortrait) { _, _ in
                sideInsets = liveSideInsets
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    sideInsets = liveSideInsets
                }
            }
            .onFoldChange { newFold in
                withAnimation(.smooth(duration: 0.35)) { fold = newFold }
            }
            .alert("Palette Already Exists", isPresented: $showDuplicateAlert) {
                Button("Save Anyway") { performSave() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A palette with these colors already exists as \"\(duplicateOfName)\".")
            }
            .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                Button("Save Anyway") { performSave() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A palette named \"\(duplicateOfName)\" already exists.")
            }
    }

    private var stageContent: some View {
        ZStack {
            formContent
                .opacity(phase == .form ? 1 : 0)
                .allowsHitTesting(phase == .form)

            if phase == .result {
                GenerationResultView(
                    name: $resultName,
                    paletteColors: $resultPaletteColors,
                    onBack: { withAnimation(.smooth(duration: 0.5)) { phase = .form } },
                    onRegenerate: {
                        pendingRefinement = ""
                        startGeneration()
                    },
                    onDescribeChange: { change in
                        pendingRefinement = change
                        startGeneration()
                    },
                    onSave: saveResult,
                    sideInsets: heldSideInsets
                )
                .environmentObject(appData)
                .transition(.blurReplace)
            }

            // Generation gives the orb room to become the waiting moment.
            if phase == .generating {
                generatingOrb
            }
        }
    }

    /// The orb, then the same copy and filling swatch row as onboarding.
    /// Stacked and centred on the stage; side by side only when the stage is
    /// too short for the stack (iPhone in landscape, iPhone Duo's outer
    /// display). Folded, the orb takes the side before the crease and the
    /// copy the side after it.
    @ViewBuilder
    private var generatingOrb: some View {
        if let fold {
            FoldSplit(fold: fold) {
                generationOrb(diameter: foldedOrbDiameter(fold))
            } controls: {
                generationCopy
                    .frame(maxWidth: 360)
            }
        } else {
            let sideBySide = !isPortrait && stageSize.height < 520
            let layout = sideBySide
                ? AnyLayout(HStackLayout(spacing: 40))
                : AnyLayout(VStackLayout(spacing: 28))
            layout {
                generationOrb(diameter: generatingOrbDiameter(sideBySide: sideBySide))
                generationCopy
                    .frame(maxWidth: sideBySide ? 360 : nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            // Held insets, so the bars changing doesn't move it; centred on the
            // screen in landscape.
            .fixedSideInsets(heldSideInsets)
        }
    }

    private func generationOrb(diameter: CGFloat) -> some View {
        GenerationOrbView(
            colors: arrivedColors,
            photo: selectedImage,
            showsProgress: true
        )
        .matchedGeometryEffect(id: "orb", in: orbNamespace)
        .frame(width: diameter, height: diameter)
        // Above the text: stretched over it, the glass bends it.
        .zIndex(1)
    }

    private var generationCopy: some View {
        VStack(spacing: 20) {
            OnboardingStepText(title: "Mixing your palette", subtitle: generationStatusText)
            GenerationSwatchRow(colors: arrivedColors, expected: paletteSize)
                .frame(maxWidth: 360)
        }
        .padding(.horizontal, 24)
        .transition(.blurFade)
    }

    /// 300 pt where there's room, shrinking with the stage so the orb and its
    /// copy always fit together.
    private func generatingOrbDiameter(sideBySide: Bool) -> CGFloat {
        guard stageSize != .zero else { return 300 }
        let fit = sideBySide
            ? min(stageSize.height * 0.7, stageSize.width * 0.4)
            : min(stageSize.width * 0.7, stageSize.height * 0.45)
        return min(300, max(160, fit))
    }

    // MARK: - Form

    @ViewBuilder
    private var formContent: some View {
        if let split = formSplit {
            splitForm(split)
        } else if showsColorGrid {
            gridForm
        } else {
            stackedForm
        }
    }

    /// Where the form splits into orb and controls: iPhone Duo's fold while
    /// half open, or down the middle of any other landscape stage (an iPhone,
    /// iPhone Duo's displays, iPad), where the side-by-side layout reads
    /// better than one long column.
    private var formSplit: Fold? {
        if let fold { return fold }
        guard !isPortrait, stageSize != .zero else { return nil }
        return Fold(frame: CGRect(x: stageSize.width / 2, y: 0, width: 0, height: stageSize.height))
    }

    /// The orb, as large as its side allows, before the split (on the left in
    /// landscape, on top in portrait), and the size, mode, colors, vibe and
    /// Generate stacked after it. The colors are a grid that scrolls on its
    /// own, between the menus and the pinned vibe field. On a short stage
    /// (an iPhone in landscape) the orb drops its copy, the menus sit side by
    /// side and Generate joins the vibe field's row, leaving the grid room.
    private func splitForm(_ fold: Fold) -> some View {
        let compact = isWideAndShort && fold.isVertical
        return FoldSplit(fold: fold) {
            VStack(spacing: 16) {
                formOrb(diameter: foldedOrbDiameter(fold, showsCopy: !compact))
                    // Above the copy: stretched over it, the glass bends it.
                    .zIndex(1)
                if !compact {
                    Text(GenerateHeaderView.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(compact ? 8 : 16)
        } controls: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: compact ? 12 : 20) {
                    generationOptions(axis: fold.isVertical && !compact ? .vertical : .horizontal)
                    scrollingColors(shortHeader: compact)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .frame(maxWidth: 640, maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity)

                // In the stack, not an inset: the grid ends above the vibe field
                // (fading out) instead of scrolling behind it.
                if phase == .form {
                    pinnedControls(compact: compact)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedColorIDs)
        .sensoryFeedback(.selection, trigger: paletteSize)
        .sensoryFeedback(.impact, trigger: phase == .generating)
    }

    /// iPad and iPhone Duo's inner display in portrait: the orb and menus
    /// stay put at the top, and only the color grid scrolls, between them
    /// and the pinned vibe field, as it does in landscape.
    private var gridForm: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                GenerateHeaderView(
                    showsOrb: phase == .form,
                    orbDiameter: formOrbDiameter,
                    colors: selectedColors,
                    orbNamespace: orbNamespace
                )
                .zIndex(1)

                generationOptions(axis: .horizontal)
                scrollingColors(shortHeader: false)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .frame(maxWidth: 640, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity)

            if phase == .form {
                pinnedControls(compact: false)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedColorIDs)
        .sensoryFeedback(.selection, trigger: paletteSize)
        .sensoryFeedback(.impact, trigger: phase == .generating)
    }

    /// The colors header over a grid that fills the space left and scrolls
    /// on its own, its cut edges fading.
    @ViewBuilder
    private func scrollingColors(shortHeader: Bool) -> some View {
        if !appData.colors.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                colorsHeader(short: shortHeader)
                ScrollView {
                    colorGrid
                        .padding(.vertical, Self.scrollFade)
                }
                .scrollDismissesKeyboard(.interactively)
                .fadingEdges([.top, .bottom], length: Self.scrollFade)
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    /// How far scrolling content fades in and out at a cut edge.
    private static var scrollFade: CGFloat { 18 }

    /// The orb's side of the fold, less room for the copy under it.
    private func foldedOrbDiameter(_ fold: Fold, showsCopy: Bool = true) -> CGFloat {
        let side = fold.span.lowerBound
        let fit = fold.isVertical
            ? min(side * 0.78, stageSize.height - (showsCopy ? 150 : 24))
            : min(side - 120, stageSize.width * 0.7)
        return min(460, max(showsCopy ? 120 : 80, fit))
    }

    /// The form's orb; it expands into the generation orb.
    private func formOrb(diameter: CGFloat) -> some View {
        ZStack {
            if phase == .form {
                GenerationOrbView(colors: selectedColors)
                    .matchedGeometryEffect(id: "orb", in: orbNamespace)
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    /// The photo chip, the vibe field and Generate, pinned above the keyboard
    /// and home indicator, like the result view's describe-change field.
    /// `compact` puts Generate beside the field, for short stages.
    private func pinnedControls(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 12) {
            if compact {
                HStack(spacing: 12) {
                    vibeField
                    if !vibeFocused && canGenerateFromSource {
                        compactGenerateButton
                            .transition(.pop)
                    }
                }
            } else {
                vibeField

                // While typing, the field's send arrow takes over — hide the bar.
                if !vibeFocused && canGenerateFromSource {
                    generateBar
                        .padding(.top, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, compact ? 8 : 24)
        .animation(.spring(response: 0.3), value: vibeFocused)
    }

    /// The orb and the options in one scrolling column, the vibe field and
    /// Generate pinned under them.
    private var stackedForm: some View {
        ScrollViewReader { scrollProxy in
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                GenerateHeaderView(
                    showsOrb: phase == .form,
                    orbDiameter: formOrbDiameter,
                    colors: selectedColors,
                    orbNamespace: orbNamespace
                )
                .zIndex(1)

                generationOptions(axis: .horizontal)
                colorsSection()

                Color.clear
                    .frame(height: 1)
                    .id("formBottom")
            }
            .padding(.horizontal)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, Self.scrollFade)
        }
        .scrollDismissesKeyboard(.interactively)
        // Ends above the vibe field and fades out into it, so nothing
        // scrolls behind the field.
        .fadingEdges(.bottom, length: Self.scrollFade)

        // Pinned above the keyboard and home indicator, like the result
        // view's describe-change field.
        if phase == .form {
            pinnedControls(compact: false)
        }
        }
        .sensoryFeedback(.selection, trigger: selectedColorIDs)
        .sensoryFeedback(.selection, trigger: paletteSize)
        .sensoryFeedback(.impact, trigger: phase == .generating)
        .onChange(of: vibeFocused) { _, focused in
            guard focused else { return }
            // Scroll fully down once the keyboard inset lands, so the color
            // strip isn't hidden behind the pinned field.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.smooth(duration: 0.35)) {
                    scrollProxy.scrollTo("formBottom", anchor: .bottom)
                }
            }
        }
        }
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

    // MARK: - Generation Options

    /// Keep the two generation controls together so they remain discoverable
    /// on both compact phones and wider iPad layouts. Menus avoid the
    /// six-segment squeeze that made the previous size control hard to use.
    /// Side by side normally; stacked above the colors on the controls side
    /// of a landscape split. The photo button sits beside them either way.
    private func generationOptions(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            : AnyLayout(VStackLayout(spacing: 10))
        return HStack(alignment: .top, spacing: 12) {
            layout {
                Menu {
                    ForEach(sizeOptions, id: \.self) { size in
                        Button {
                            paletteSize = size
                        } label: {
                            if size == paletteSize {
                                Label("\(size) colors", systemImage: "checkmark")
                            } else {
                                Text("\(size) colors")
                            }
                        }
                    }
                } label: {
                    generationOptionLabel(
                        title: "Palette Size",
                        value: "\(paletteSize) colors",
                        systemImage: "square.stack.3d.up"
                    )
                }
                .accessibilityLabel("Palette size")

                if canChooseMode {
                    Menu {
                        ForEach(HarmonyScheme.allCases) { option in
                            Button {
                                scheme = option
                            } label: {
                                if option == scheme {
                                    Label(option.displayName, systemImage: "checkmark")
                                } else {
                                    Text(option.displayName)
                                }
                            }
                        }
                    } label: {
                        generationOptionLabel(
                            title: "Mode",
                            value: scheme.displayName,
                            systemImage: "paintpalette"
                        )
                    }
                    .accessibilityLabel("Palette mode")
                    .transition(.scale(scale: 0.96, anchor: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: canChooseMode)

            // The photo source sits with the other inputs, matching their height.
            imageMenuButton(axis: axis)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func generationOptionLabel(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 2)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .liquidGlass(.interactive, in: .rect(cornerRadius: 14))
    }

    // MARK: - Colors

    /// The user's colors to start from, as a strip (compact portrait; larger
    /// stages use `scrollingColors`).
    @ViewBuilder
    private func colorsSection() -> some View {
        if !appData.colors.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                colorsHeader(short: false)

                colorStrip
            }
        }
    }

    private func colorsHeader(short: Bool) -> some View {
        HStack(spacing: 6) {
            Text(short ? "Your Colors" : "Start From Your Colors")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !selectedColorIDs.isEmpty {
                Text("· \(selectedColorIDs.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Button("Clear") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedColorIDs.removeAll()
                    }
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            Spacer(minLength: 8)
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 14)], spacing: 18) {
            ForEach(appData.colors) { colorItem in
                colorSwatch(colorItem, diameter: 64)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
    }

    private var colorStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(appData.colors) { colorItem in
                    colorSwatch(colorItem)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.x > 4
        } action: { _, scrolled in
            colorsFadeLeading = scrolled
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            geo.contentOffset.x < geo.contentSize.width - geo.containerSize.width - 4
        } action: { _, more in
            colorsFadeTrailing = more
        }
        // Soften the edges while there is off-screen content, so
        // swatches fade out instead of cutting off harshly.
        .mask {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                    .frame(width: colorsFadeLeading ? 28 : 0)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: colorsFadeTrailing ? 28 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: colorsFadeLeading)
            .animation(.easeInOut(duration: 0.2), value: colorsFadeTrailing)
        }
    }

    private func colorSwatch(_ colorItem: ColorViewModel, diameter: CGFloat = 54) -> some View {
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
                        .frame(width: diameter, height: diameter)
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
                            .transition(.pop)
                    }
                }

                Text(colorItem.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: diameter + 8)
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityLabel(Text(colorItem.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Vibe

    private var vibeField: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "apple.intelligence")
                    .font(.title3)
                    .foregroundStyle(glowGradient)

                TextField("Warm autumn forest, neon arcade…", text: $vibeDescription)
                    .font(.body)
                    .focused($vibeFocused)
                    .submitLabel(.go)
                    .onSubmit { if hasInput { startGeneration() } }

                if vibeFocused {
                    Button(action: startGeneration) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(hasInput ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    }
                    .disabled(!hasInput)
                    .transition(.pop)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .liquidGlass(.interactive, in: .capsule)

        }
    }

    /// Picks up a color handed off from a color detail view's "Generate Palette" button.
    private func consumePendingColor() {
        guard let id = appData.pendingGenerateColorID else { return }
        appData.pendingGenerateColorID = nil
        guard appData.colors.contains(where: { $0.id == id }) else { return }
        withAnimation(.smooth(duration: 0.4)) {
            phase = .form
            selectedColorIDs.insert(id)
        }
    }

    private var hasInput: Bool {
        !selectedColorIDs.isEmpty
            || !vibeDescription.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedImage != nil
    }

    /// Modes shape every generation now, including one from a vibe alone.
    private var canChooseMode: Bool {
        canGenerateFromSource || !vibeDescription.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canGenerateFromSource: Bool {
        !selectedColorIDs.isEmpty || selectedImage != nil
    }

    private var generationStatusText: String {
        let vibe = vibeDescription.trimmingCharacters(in: .whitespaces)
        if !vibe.isEmpty { return "“\(vibe)”" }
        if selectedImage != nil { return "Pulling colors out of your photo." }
        if !selectedColorIDs.isEmpty { return "Building around your colors." }
        return "Composing something new."
    }

    // MARK: - Generate Button

    private var generateBar: some View {
        GlassContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    startGeneration()
                } label: {
                    Text("Generate Palette")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 6)
                }
                .glassButton(prominent: true)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Generate as a single glass button, beside the vibe field on short stages.
    private var compactGenerateButton: some View {
        Button {
            startGeneration()
        } label: {
            Text("Generate")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .glassButton(prominent: true)
        .keyboardShortcut(.return, modifiers: .command)
        .fixedSize()
    }

    /// Square: as tall as the menus beside it, or as one of them when they're
    /// stacked (`axis` is the menus' axis).
    @ViewBuilder
    private func imageMenuButton(axis: Axis) -> some View {
        Menu {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            // A PhotosPicker nested directly in a Menu never presents, so the
            // menu item just flips a flag and the picker is driven by the
            // `.photosPicker(isPresented:)` modifier below.
            Button {
                showPhotoPicker = true
            } label: {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        } label: {
            // The chosen photo fills the button; tapping it again replaces it.
            ZStack {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .transition(.opacity)
                }
            }
            .frame(width: 52)
            .frame(minHeight: 52, maxHeight: axis == .horizontal ? .infinity : 52)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                if selectedImage != nil {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.tint, lineWidth: 2.5)
                        .transition(.opacity)
                }
            }
            .contentShape(.rect(cornerRadius: 14))
            .liquidGlass(.interactive, in: .rect(cornerRadius: 14))
        }
        .accessibilityLabel(selectedImage == nil ? "Add photo" : "Replace photo")
        .overlay(alignment: .topTrailing) {
            if selectedImage != nil {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedImage = nil
                        photosPickerItem = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                        // A larger target than the glyph.
                        .padding(6)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .offset(x: 10, y: -10)
                .accessibilityLabel("Remove photo")
                .transition(.pop)
            }
        }
        .animation(.spring(response: 0.3), value: selectedImage != nil)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photosPickerItem, matching: .images)
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
                resultPaletteColors = palette.paletteColors
                #if DEBUG
                // `-generateHold YES` keeps the waiting moment up for screenshots.
                if UserDefaults.standard.bool(forKey: "generateHold") {
                    try? await Task.sleep(for: .seconds(8))
                }
                #endif
                // Let the last drop settle before revealing the result
                try? await Task.sleep(for: .milliseconds(900))
                withAnimation(.smooth(duration: 0.7)) { phase = .result }
            } catch is CancellationError {
                withAnimation(.smooth(duration: 0.5)) { phase = .form }
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
                withAnimation(.smooth(duration: 0.5)) { phase = .form }
            }
        }
    }

    private func saveResult() {
        guard resultPaletteColors.count >= 2 else { return }
        if let existing = appData.existingPalette(matching: resultPaletteColors.map(\.hex)) {
            duplicateOfName = existing.name
            showDuplicateAlert = true
            return
        }
        let trimmed = resultName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let existing = appData.existingPalette(named: trimmed) {
            duplicateOfName = existing.name
            showNameDuplicateAlert = true
            return
        }
        performSave()
    }

    private func performSave() {
        let trimmed = resultName.trimmingCharacters(in: .whitespaces)
        appData.palettes.append(PaletteViewModel(
            name: trimmed.isEmpty ? "Generated Palette" : trimmed,
            paletteColors: resultPaletteColors,
            isGenerated: true
        ))

        // Add any newly generated colors to the Colors library.
        appData.addPaletteColorsToLibrary(resultPaletteColors, isGenerated: true)

        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        withAnimation(.smooth(duration: 0.5)) { phase = .form }
        resetForm()
    }

    /// Fresh form for the next generation after a palette was saved.
    /// Result state is left alone so the outgoing result view doesn't blank
    /// mid-transition; it's overwritten by the next generation anyway.
    private func resetForm() {
        paletteSize = 4
        selectedColorIDs = []
        scheme = .auto
        vibeDescription = ""
        selectedImage = nil
        photosPickerItem = nil
        pendingRefinement = ""
        arrivedColors = []
    }

    private func performGeneration(onColors: @escaping @MainActor ([Color]) -> Void) async throws -> PaletteViewModel {
        var baseColors: [PaletteGenerator.BaseColor] = appData.colors
            .filter { selectedColorIDs.contains($0.id) }
            .map { PaletteGenerator.BaseColor(hex: $0.HEX, name: $0.name) }

        let combinedVibe = [vibeDescription, pendingRefinement]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        let hasVibe = !combinedVibe.isEmpty

        if let image = selectedImage {
            // Pull enough colors straight from the image to fill the whole
            // palette (not a fixed handful), so an image-based palette is
            // built FROM the image rather than seeded with a few colors and
            // padded out with synthesized harmony colors.
            let needed = max(1, paletteSize - baseColors.count)
            let extracted = try ImageColorExtractor.extractColors(from: image, count: needed)
            baseColors += extracted.map { PaletteGenerator.BaseColor(hex: $0.hex, name: "") }
        }

        // Without a vibe, an image (or hand-picked colors + image) must yield
        // ONLY the colors actually supplied — never invented ones. Clamping
        // the target to what we have makes the generator lock them verbatim
        // and synthesize nothing; an image with few distinct colors simply
        // produces a smaller palette. With a vibe, keep the full requested
        // size so the AI may expand to fill whatever the image didn't cover.
        // The pure color-seed path (colors selected, no image) is unchanged:
        // it still builds a harmony palette around the seeds.
        let targetSize = (selectedImage != nil && !hasVibe)
            ? min(paletteSize, baseColors.count)
            : paletteSize

        return try await PaletteGenerator.generate(
            baseColors: baseColors,
            size: targetSize,
            vibe: combinedVibe,
            scheme: canChooseMode ? scheme : .auto,
            existingNames: appData.palettes.map { $0.name },
            onPartialColors: onColors
        )
    }
}

/// Orb + description text at the top of the form.
@available(iOS 26.0, *)
private struct GenerateHeaderView: View {
    let showsOrb: Bool
    let orbDiameter: CGFloat
    let colors: [Color]
    let orbNamespace: Namespace.ID

    static let description = "Describe a vibe, start from your colors, or pull them from a photo — Apple Intelligence composes the palette."

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            // The orb is part of the scroll content, so it moves with the
            // view and is pushed up by the keyboard instead of overlaying.
            // Its matched counterpart expands into the generation orb.
            ZStack {
                if showsOrb {
                    GenerationOrbView(colors: colors)
                        .matchedGeometryEffect(id: "orb", in: orbNamespace)
                        .frame(width: orbDiameter, height: orbDiameter)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: orbDiameter)
            .padding(.top, 8)
            .zIndex(1)

            Text(Self.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    if #available(iOS 26.0, *) {
        GenerateView()
            .environmentObject(AppData())
    }
}
