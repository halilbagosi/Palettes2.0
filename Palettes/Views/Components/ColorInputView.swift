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

/// Shared color input surface used by the palette create/add sheets.
/// Hosts own the draft; this view resolves colors and reports them via `onAdd`
/// (single colors) and `onScanPalette` (multi-color image extraction).
/// Duplicate hexes in `excludedHexes` are rejected with a toast, and library
/// rows for them show an "Added" state.
/// Not a ScrollView — hosts embed it in their own scroll container.
struct ColorInputView: View {
    var sources: [ColorInputSource] = [.pick, .scan]
    var initialSource: ColorInputSource? = nil
    var scanExtraction: ScanExtraction = .dominant
    var excludedHexes: Set<String> = []   // uppercased "#RRGGBB"
    var addButtonTitle: String = "Add Color"
    var onAdd: (ColorInputEntry) -> Void
    var onScanPalette: (([ColorInputEntry]) -> Void)? = nil

    @EnvironmentObject var appData: AppData

    @State private var source: ColorInputSource = .pick
    @State private var didSetInitialSource = false

    // Pick state
    @State private var pickColor: Color = .red
    @State private var pickName = ""
    @State private var currentHEX = ""
    @State private var hexError = false

    // Scan state
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var didCameraCapture = false
    @State private var showTrueToneAlert = false
    @State private var scanName = ""
    @State private var temperatureValue: Double = 0.5
    @State private var saturationValue: Double = 0.5
    @State private var brightnessValue: Double = 0.5
    @State private var baseR: Double = 128
    @State private var baseG: Double = 128
    @State private var baseB: Double = 128
    @State private var hasExtractedColor = false

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

    var body: some View {
        VStack(spacing: 0) {
            if sources.count > 1 {
                Picker("Input", selection: $source) {
                    ForEach(sources, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
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
        .sensoryFeedback(.selection, trigger: source)
        .onAppear {
            if !didSetInitialSource {
                source = initialSource ?? sources.first ?? .pick
                didSetInitialSource = true
            }
        }
        .onChange(of: source) { _, newValue in
            if newValue == .scan { showTrueToneAlert = true }
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
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $selectedImage, didCapture: $didCameraCapture, isPresented: $showCamera)
        }
        .alert("Turn Off True Tone", isPresented: $showTrueToneAlert) {
            Button("Got It") {}
        } message: {
            Text("For accurate color scanning, turn off True Tone in Settings → Display & Brightness. True Tone adjusts your screen's warmth, which can affect how scanned colors appear.")
        }
    }

    // MARK: - Pick

    private var pickContent: some View {
        VStack(spacing: 0) {
            InteractiveColorPicker(
                mode: .combined,
                colorValue: $pickColor,
                internalName: $pickName,
                currentHEX: $currentHEX,
                hexError: $hexError
            )

            Button {
                addFromPick()
            } label: {
                Label(addButtonTitle, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(10)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .padding(.horizontal)
            .padding(.top, 16)
            .disabled(currentHEX.count != 6 || hexError)
        }
    }

    // MARK: - Scan

    private var scanContent: some View {
        VStack(spacing: 16) {
            photoArea

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .tint(.primary)
                }

                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                }
                .tint(.primary)
            }
            .padding(.horizontal)

            if case .dominant = scanExtraction, hasExtractedColor {
                dominantScanControls
            }
        }
    }

    private var dominantScanControls: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(adjustedColor.gradient)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
                .animation(.easeOut(duration: 0.15), value: temperatureValue)
                .animation(.easeOut(duration: 0.15), value: saturationValue)
                .animation(.easeOut(duration: 0.15), value: brightnessValue)

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
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .padding(.horizontal)

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

            TextField("Color Name", text: $scanName)
                .font(.system(size: 18, weight: .medium))
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

            Button {
                addFromScan()
            } label: {
                Label(addButtonTitle, systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(10)
            }
            .buttonStyle(.glassProminent)
            .tint(.accentColor)
            .padding(.horizontal)
        }
    }

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(scanPlaceholderText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var scanPlaceholderText: String {
        if case .palette = scanExtraction {
            return "Pick or take a photo to extract colors"
        }
        return "Pick or take a photo to extract the dominant color"
    }

    // MARK: - Library

    private var libraryContent: some View {
        LazyVStack(spacing: 10) {
            if appData.colors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "circle.grid.cross")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No saved colors yet. Use Pick or Scan to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(appData.colors) { colorItem in
                    libraryRow(for: colorItem)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func libraryRow(for colorItem: ColorViewModel) -> some View {
        let alreadyIn = excludedHexes.contains(colorItem.HEX.uppercased())

        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorItem.color.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(colorItem.name)
                    .font(.system(size: 15, weight: .semibold))
                HStack(spacing: 6) {
                    Text(colorItem.HEX)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(colorItem.color.rgbString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.secondary)
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
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .opacity(alreadyIn ? 0.55 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !alreadyIn else { return }
            haptic()
            onAdd(ColorInputEntry(name: colorItem.name, hex: colorItem.HEX, color: colorItem.color))
        }
        .animation(.spring(response: 0.25), value: alreadyIn)
    }

    // MARK: - Actions

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
        currentHEX = ""
        pickName = ""
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

    private func autoFillPickName() {
        let raw = currentHEX.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count == 6, Color(hex: raw) != nil else { return }
        pickName = autoName(forRawHex: raw)
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
