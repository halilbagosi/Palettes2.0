import SwiftUI
import PhotosUI

/// A resolved color produced by any input source.
struct ColorInputEntry {
    let name: String
    let hex: String   // "#RRGGBB"
    let color: Color
}

enum ColorInputSource: String, CaseIterable {
    case pick = "Pick"
    case scan = "Scan"
    case library = "Library"
}

enum ScanExtraction {
    case dominant
    case palette(count: Int)
}

/// How the colors pulled from a photo join the colors already in a palette.
enum ScanMergeMode {
    case replace
    case append
}

/// Lets a host drive the add action from its own UI (e.g. a toolbar Create
/// button) instead of the inline bottom button. The view keeps `canAdd` and
/// `previewHex` current and points `submit` at the active source's add action.
@MainActor
@Observable
final class ColorInputController {
    var canAdd = false
    /// "#RRGGBB" of the color being composed (Pick, or Scan once a photo is
    /// in); nil when there is none.
    var previewHex: String? = nil
    var previewColor: Color? { previewHex.flatMap { Color(hex: $0) } }
    @ObservationIgnored var submit: () -> Void = {}
}

/// Shared color input surface used by the New Color sheet and the palette
/// create/add sheets. Hosts own the draft; this view resolves colors and
/// reports them via `onAdd` (single colors) and `onScanPalette` (multi-color
/// image extraction). Colors whose hex is in `excludedHexes` can't be added
/// again: the add button and library rows show them as added.
/// Not a ScrollView — hosts embed it in their own scroll container.
struct ColorInputView: View {
    var sources: [ColorInputSource] = [.pick, .scan]
    var initialSource: ColorInputSource? = nil
    var scanExtraction: ScanExtraction = .dominant
    var excludedHexes: Set<String> = []   // uppercased "#RRGGBB"
    var addButtonTitle: String = "Add Color"
    var onAdd: (ColorInputEntry) -> Void
    var onScanPalette: (([ColorInputEntry]) -> Void)? = nil
    var showsAddButton: Bool = true
    /// Small swatch beside the name field. Hosts that show their own large
    /// preview (driven by `controller.previewHex`) turn it off.
    var showsPreview: Bool = true
    var controller: ColorInputController? = nil

    // isSourceTypeAvailable(.camera) probes capture hardware and is slow;
    // calling it during body evaluation makes every keystroke pay for it.
    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    @EnvironmentObject var appData: AppData

    @State private var source: ColorInputSource = .pick
    @State private var didSetInitialSource = false

    // Pick state — starts on a fresh, pleasant color rather than pure red.
    @State private var pickColor = Color(hue: Double.random(in: 0..<1), saturation: 0.65, brightness: 0.88)
    @State private var pickName = ""
    /// The last name we filled in, so the name follows the color only until
    /// the user types their own.
    @State private var lastAutoPickName = ""
    @State private var currentHEX = ""
    @State private var hexError = false

    // Scan state
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var didCameraCapture = false
    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false
    @State private var scanName = ""
    @State private var temperatureValue: Double = 0.5
    @State private var saturationValue: Double = 0.5
    @State private var brightnessValue: Double = 0.5
    @State private var baseR: Double = 128
    @State private var baseG: Double = 128
    @State private var baseB: Double = 128
    @State private var hasExtractedColor = false
    @State private var showPhotoPicker = false

    // Library state
    @State private var librarySearch = ""

    private var adjustedRGB: (r: Double, g: Double, b: Double) {
        guard hasExtractedColor else { return (128, 128, 128) }
        return ColorAdjustment.apply(
            baseR: baseR, baseG: baseG, baseB: baseB,
            temperature: temperatureValue,
            saturation: saturationValue,
            brightness: brightnessValue
        )
    }

    private var adjustedHex: String {
        let c = adjustedRGB
        return ColorAdjustment.hexString(r: c.r, g: c.g, b: c.b)
    }

    private var adjustedColor: Color {
        let c = adjustedRGB
        return ColorAdjustment.color(r: c.r, g: c.g, b: c.b)
    }

    private var pickIsValid: Bool { currentHEX.count == 6 && !hexError }
    private var isPickDuplicate: Bool { excludedHexes.contains("#\(currentHEX.uppercased())") }
    private var isScanDuplicate: Bool { excludedHexes.contains(adjustedHex.uppercased()) }

    /// The color being composed, for hosts with their own preview.
    private var composedHex: String? {
        switch source {
        case .pick: return pickIsValid ? "#\(currentHEX.uppercased())" : nil
        case .scan: return hasExtractedColor ? adjustedHex : nil
        case .library: return nil
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            if sources.count > 1 {
                Picker("Source", selection: $source) {
                    ForEach(sources, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
            }

            switch source {
            case .pick:
                pickContent
            case .scan:
                scanContent
            case .library:
                libraryContent
            }
        }
        .padding(.top, 16)
        .sensoryFeedback(.selection, trigger: source)
        .onAppear {
            if !didSetInitialSource {
                source = initialSource ?? sources.first ?? .pick
                didSetInitialSource = true
            }
            controller?.submit = { submitCurrentSource() }
            controller?.canAdd = canAddCurrentSource
            controller?.previewHex = composedHex
            presentTrueToneWarningIfNeeded()
        }
        .onChange(of: source) { _, newValue in
            if newValue == .scan { presentTrueToneWarningIfNeeded() }
        }
        .onChange(of: canAddCurrentSource) { _, newValue in
            controller?.canAdd = newValue
        }
        .onChange(of: composedHex) { _, newValue in
            controller?.previewHex = newValue
        }
        .onChange(of: currentHEX) { _, _ in
            if source == .pick { autoFillPickName() }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    extract(from: image)
                }
            }
        }
        .onChange(of: didCameraCapture) { _, captured in
            if captured, let image = selectedImage {
                extract(from: image)
                didCameraCapture = false
            }
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage, didCapture: $didCameraCapture, isPresented: $showCamera)
        }
        .alert("Turn Off True Tone", isPresented: $showTrueToneAlert) {
            Button("Got It") { didAcknowledgeTrueToneWarning = true }
        } message: {
            Text("For accurate color scanning, turn off True Tone in Settings → Display & Brightness. True Tone adjusts your screen's warmth, which can affect how scanned colors appear.")
        }
    }

    private func presentTrueToneWarningIfNeeded() {
        guard source == .scan, !didAcknowledgeTrueToneWarning else { return }
        showTrueToneAlert = true
    }

    // MARK: - Add Button

    /// Full-width primary action. A color that's already in the draft reads
    /// "Already Added" instead of failing with a toast after the tap.
    private func addButton(isDuplicate: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(
                isDuplicate ? "Already Added" : addButtonTitle,
                systemImage: isDuplicate ? "checkmark.circle.fill" : "plus.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .glassButton(prominent: true)
        .tint(.accentColor)
        .disabled(!isEnabled || isDuplicate)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: isDuplicate)
    }

    // MARK: - Pick

    private var pickContent: some View {
        VStack(spacing: 16) {
            InteractiveColorPicker(
                showsSwatch: showsPreview,
                colorValue: $pickColor,
                internalName: $pickName,
                currentHEX: $currentHEX,
                hexError: $hexError
            )

            if showsAddButton {
                addButton(isDuplicate: isPickDuplicate, isEnabled: pickIsValid) {
                    addFromPick()
                }
            }
        }
    }

    // MARK: - Scan

    private var scanContent: some View {
        VStack(spacing: 16) {
            photoArea

            if case .dominant = scanExtraction, hasExtractedColor {
                dominantScanControls
            }
        }
    }

    private var dominantScanControls: some View {
        VStack(spacing: 16) {
            ColorNameField(color: showsPreview ? adjustedColor : nil, name: $scanName)

            VStack(spacing: 8) {
                SheetSectionHeader(title: "Fine-tune")

                VStack(spacing: 18) {
                    AdjustmentSlider(
                        title: "Temperature",
                        valueLabel: ColorAdjustment.offsetLabel(temperatureValue, positive: "warm", negative: "cool"),
                        leftLabel: "Cool",
                        rightLabel: "Warm",
                        value: $temperatureValue
                    )
                    AdjustmentSlider(
                        title: "Saturation",
                        valueLabel: ColorAdjustment.offsetLabel(saturationValue),
                        leftLabel: "Muted",
                        rightLabel: "Vivid",
                        value: $saturationValue
                    )
                    AdjustmentSlider(
                        title: "Brightness",
                        valueLabel: ColorAdjustment.offsetLabel(brightnessValue),
                        leftLabel: "Dark",
                        rightLabel: "Light",
                        value: $brightnessValue
                    )
                }
                .padding(16)
                .liquidGlass(.regular, in: .rect(cornerRadius: 20))
                .padding(.horizontal)
            }

            VStack(spacing: 8) {
                SheetSectionHeader(title: "Values")

                EditableValuesView(color: adjustedColor) { newColor in
                    let c = newColor.rgbComponents
                    baseR = Double(Int(round(c.r)))
                    baseG = Double(Int(round(c.g)))
                    baseB = Double(Int(round(c.b)))

                    temperatureValue = 0.5
                    saturationValue = 0.5
                    brightnessValue = 0.5
                }
                .padding(.horizontal)
            }

            if showsAddButton {
                addButton(isDuplicate: isScanDuplicate, isEnabled: hasExtractedColor) {
                    addFromScan()
                }
            }
        }
    }

    /// One surface for the photo: an empty prompt with Camera / Photos, then
    /// the photo itself with a replace menu (and, for a single color, a tap
    /// to pick the exact spot).
    @ViewBuilder
    private var photoArea: some View {
        Group {
            if let image = selectedImage {
                Color.clear
                    .frame(height: 220)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .bottom) {
                        if case .dominant = scanExtraction {
                            Label("Tap to pick a color", systemImage: "eyedropper")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .liquidGlass(.regular, in: .capsule)
                                .padding(.bottom, 12)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onTapGesture {
                        if case .dominant = scanExtraction { showPhotoPicker = true }
                    }
                    .overlay(alignment: .topTrailing) {
                        replacePhotoMenu
                    }
            } else {
                emptyPhotoPrompt
            }
        }
        .padding(.horizontal)
        .fullScreenCover(isPresented: $showPhotoPicker) {
            if let image = selectedImage {
                PhotoColorPickerView(
                    image: image,
                    initialRGB: hasExtractedColor ? (baseR, baseG, baseB) : nil,
                    onUse: { rgb in
                        baseR = rgb.r
                        baseG = rgb.g
                        baseB = rgb.b
                        temperatureValue = 0.5
                        saturationValue = 0.5
                        brightnessValue = 0.5
                        hasExtractedColor = true
                        let hex = String(
                            format: "%02X%02X%02X",
                            Int(round(baseR)), Int(round(baseG)), Int(round(baseB))
                        )
                        scanName = autoName(forRawHex: hex)
                    }
                )
            }
        }
    }

    private var emptyPhotoPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(scanPlaceholderText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                if Self.cameraAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                }

                Button {
                    showPhotoLibrary = true
                } label: {
                    Label("Photos", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.large)
            .tint(.primary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220)
        .liquidGlass(.regular, in: .rect(cornerRadius: 20))
    }

    private var replacePhotoMenu: some View {
        Menu {
            if Self.cameraAvailable {
                Button("Take Photo", systemImage: "camera") { showCamera = true }
            }
            Button("Choose Photo", systemImage: "photo.on.rectangle") { showPhotoLibrary = true }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .liquidGlass(.interactive, in: .circle)
        }
        .padding(10)
        .accessibilityLabel("Replace Photo")
    }

    private var scanPlaceholderText: String {
        if case .palette = scanExtraction {
            return "Take or choose a photo to pull a palette from it."
        }
        return "Take or choose a photo to pull its main color."
    }

    // MARK: - Library

    /// Newest first, like the library's default sort, filtered by the search.
    private var libraryColors: [ColorViewModel] {
        let items = Array(appData.colors.reversed())
        let query = librarySearch.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.HEX.localizedCaseInsensitiveContains(query)
        }
    }

    private var libraryContent: some View {
        LazyVStack(spacing: 10) {
            if appData.colors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No saved colors yet. Use Pick or Scan to add one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                if appData.colors.count > 6 {
                    librarySearchField
                }

                let colors = libraryColors
                if colors.isEmpty {
                    Text("No colors match \u{201C}\(librarySearch)\u{201D}.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(colors) { colorItem in
                        libraryRow(for: colorItem)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var librarySearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search Colors", text: $librarySearch)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !librarySearch.isEmpty {
                Button {
                    librarySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .liquidGlass(.regular, in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private func libraryRow(for colorItem: ColorViewModel) -> some View {
        let alreadyIn = excludedHexes.contains(colorItem.HEX.uppercased())

        Button {
            haptic()
            onAdd(ColorInputEntry(name: colorItem.name, hex: colorItem.HEX, color: colorItem.color))
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorItem.color.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(colorItem.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(colorItem.HEX)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if alreadyIn {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(alreadyIn)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
        .opacity(alreadyIn ? 0.55 : 1)
        .animation(.spring(response: 0.25), value: alreadyIn)
        .accessibilityLabel(alreadyIn ? "\(colorItem.name), added" : "Add \(colorItem.name)")
    }

    // MARK: - Actions

    /// Whether the active source has a valid draft to add. Mirrors the
    /// inline buttons' enabled states for hosts using a toolbar button.
    private var canAddCurrentSource: Bool {
        switch source {
        case .pick: return pickIsValid && !isPickDuplicate
        case .scan: return hasExtractedColor && !isScanDuplicate
        case .library: return false   // rows add directly on tap
        }
    }

    private func submitCurrentSource() {
        switch source {
        case .pick: addFromPick()
        case .scan: addFromScan()
        case .library: break
        }
    }

    private func addFromPick() {
        let raw = currentHEX.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count == 6, Color(hex: raw) != nil else {
            hexError = true
            return
        }
        let hex = "#\(raw)"
        guard notDuplicate(hex) else { return }

        let trimmedName = pickName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? autoName(forRawHex: raw) : trimmedName

        haptic()
        onAdd(ColorInputEntry(name: name, hex: hex, color: pickColor))
    }

    private func addFromScan() {
        guard hasExtractedColor else { return }
        let hex = adjustedHex
        guard notDuplicate(hex) else { return }

        let trimmedName = scanName.trimmingCharacters(in: .whitespaces)
        let name = trimmedName.isEmpty ? autoName(forRawHex: String(hex.dropFirst())) : trimmedName

        haptic()
        onAdd(ColorInputEntry(name: name, hex: hex, color: adjustedColor))
    }

    private func notDuplicate(_ hex: String) -> Bool {
        if excludedHexes.contains(hex.uppercased()) {
            ToastManager.shared.show("Already in this palette", icon: "exclamationmark.circle.fill")
            return false
        }
        return true
    }

    private func extract(from image: UIImage) {
        switch scanExtraction {
        case .dominant:
            do {
                let rgb = try ImageColorExtractor.extractDominantRGB(from: image)
                baseR = rgb.r
                baseG = rgb.g
                baseB = rgb.b
                temperatureValue = 0.5
                saturationValue = 0.5
                brightnessValue = 0.5
                hasExtractedColor = true

                let hex = String(format: "%02X%02X%02X", Int(round(rgb.r)), Int(round(rgb.g)), Int(round(rgb.b)))
                scanName = autoName(forRawHex: hex)
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
        case .palette(let count):
            do {
                let extracted = try ImageColorExtractor.extractColors(from: image, count: count)
                let entries = extracted.compactMap { item -> ColorInputEntry? in
                    guard let color = Color(hex: String(item.hex.dropFirst())) else { return nil }
                    return ColorInputEntry(name: item.name, hex: item.hex, color: color)
                }
                onScanPalette?(entries)
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
        }
    }

    /// Names the picked color after its hex until the user types a name of
    /// their own; from then on their name stays put while the color changes.
    private func autoFillPickName() {
        let raw = currentHEX.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count == 6, Color(hex: raw) != nil else { return }
        let suggestion = autoName(forRawHex: raw)
        if pickName.isEmpty || pickName == lastAutoPickName {
            pickName = suggestion
        }
        lastAutoPickName = suggestion
    }

    /// Existing-color lookup first, then ColorNamer — identical naming across all sheets.
    private func autoName(forRawHex raw: String) -> String {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare("#\(raw)") == .orderedSame }) {
            return existing.name
        }
        return ColorNamer.name(forHex: raw)
    }

    private func haptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
