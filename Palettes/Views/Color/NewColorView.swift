import SwiftUI
import PhotosUI

struct NewColorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    enum InputMode: String, CaseIterable {
        case pick = "Pick"
        case scan = "Scan"
    }

    @State private var inputMode: InputMode = .pick

    // Shared source of truth
    @State private var colorName = ""
    @State private var currentHEX = ""
    @State private var colorValue: Color = .red
    @State private var hexError = false

    // Scan mode
    @State private var selectedImage: UIImage?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var didCameraCapture = false
    @State private var scanTemperatureValue: Double = 0.5
    @State private var scanSaturationValue: Double = 0.5
    @State private var scanBrightnessValue: Double = 0.5
    @State private var showTrueToneAlert = false

    // Base color from extraction (0–255)
    @State private var baseR: Double = 128
    @State private var baseG: Double = 128
    @State private var baseB: Double = 128
    @State private var hasExtractedColor = false

    // MARK: - Create pipeline (single source of truth per mode)

    private var resolvedHexAndColor: (hex: String, color: Color)? {
        switch inputMode {
        case .pick:
            let raw = currentHEX.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard raw.count == 6, let color = Color(hex: raw) else { return nil }
            return ("#\(raw)", color)
        case .scan:
            guard hasExtractedColor else { return nil }
            return (adjustedHex, adjustedSwiftColor)
        }
    }

    private var canCreate: Bool {
        resolvedHexAndColor != nil && !colorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Adjusted Color (Temperature + Saturation + Brightness)

    private var adjustedRGB: (r: Double, g: Double, b: Double) {
        guard hasExtractedColor else { return (128, 128, 128) }

        let tempFactor = (scanTemperatureValue - 0.5) * 2.0
        let tempAmount = tempFactor * 40.0

        let rTemp = min(255, max(0, baseR + tempAmount))
        let gTemp = min(255, max(0, baseG + tempAmount * 0.15))
        let bTemp = min(255, max(0, baseB - tempAmount))

        let uiColor = UIColor(
            red: rTemp / 255.0,
            green: gTemp / 255.0,
            blue: bTemp / 255.0,
            alpha: 1.0
        )
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        let satFactor = (scanSaturationValue - 0.5) * 2.0
        let newSat = min(1, max(0, s + CGFloat(satFactor) * 0.5))

        let briFactor = (scanBrightnessValue - 0.5) * 2.0
        let newBri = min(1, max(0, b + CGFloat(briFactor) * 0.5))

        let adjusted = UIColor(hue: h, saturation: newSat, brightness: newBri, alpha: 1)
        var rOut: CGFloat = 0, gOut: CGFloat = 0, bOut: CGFloat = 0
        adjusted.getRed(&rOut, green: &gOut, blue: &bOut, alpha: &a)

        return (
            min(255, max(0, Double(rOut) * 255)),
            min(255, max(0, Double(gOut) * 255)),
            min(255, max(0, Double(bOut) * 255))
        )
    }

    private var adjustedHex: String {
        let c = adjustedRGB
        return String(format: "#%02X%02X%02X", Int(round(c.r)), Int(round(c.g)), Int(round(c.b)))
    }

    private var adjustedSwiftColor: Color {
        let c = adjustedRGB
        return Color(red: c.r / 255.0, green: c.g / 255.0, blue: c.b / 255.0)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Input", selection: $inputMode) {
                    ForEach(InputMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(6)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 12)

                switch inputMode {
                case .pick:
                    pickContent
                case .scan:
                    scanContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Color")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createColor() }
                        .buttonStyle(.glassProminent)
                        .fontWeight(.semibold)
                        .disabled(!canCreate)
                }
            }
            .sensoryFeedback(.selection, trigger: inputMode)
            .onChange(of: inputMode) { _, newValue in
                if newValue == .scan {
                    showTrueToneAlert = true
                }
            }
            .onChange(of: currentHEX) { _, _ in
                if inputMode == .pick { autoFillName() }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        extractDominantColor(from: image)
                    }
                }
            }
            .onChange(of: didCameraCapture) { _, captured in
                if captured, let image = selectedImage {
                    extractDominantColor(from: image)
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
    }

    // MARK: - Pick Mode

    private var pickContent: some View {
        ScrollView {
            InteractiveColorPicker(
                colorValue: $colorValue,
                internalName: $colorName,
                currentHEX: $currentHEX,
                hexError: $hexError
            )
            .padding(.bottom, 20)
        }
    }

    // MARK: - Scan Mode

    private var scanContent: some View {
        ScrollView {
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
                        }
                        .buttonStyle(.glass)
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

                if hasExtractedColor {
                    // Live preview of the adjusted color
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(adjustedSwiftColor.gradient)
                        .frame(height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .animation(.easeOut(duration: 0.15), value: scanTemperatureValue)
                        .animation(.easeOut(duration: 0.15), value: scanSaturationValue)
                        .animation(.easeOut(duration: 0.15), value: scanBrightnessValue)

                    VStack(spacing: 18) {
                        AdjustmentSlider(
                            title: "Temperature",
                            valueLabel: offsetLabel(scanTemperatureValue, positive: "warm", negative: "cool"),
                            leftLabel: "Cool",
                            rightLabel: "Warm",
                            value: $scanTemperatureValue
                        )
                        AdjustmentSlider(
                            title: "Saturation",
                            valueLabel: offsetLabel(scanSaturationValue),
                            leftLabel: "Muted",
                            rightLabel: "Vivid",
                            value: $scanSaturationValue
                        )
                        AdjustmentSlider(
                            title: "Brightness",
                            valueLabel: offsetLabel(scanBrightnessValue),
                            leftLabel: "Dark",
                            rightLabel: "Light",
                            value: $scanBrightnessValue
                        )
                    }
                    .padding(14)
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .padding(.horizontal)

                    // Fine-tune exact values
                    EditableValuesView(color: adjustedSwiftColor) { newColor in
                        let uiColor = UIColor(newColor)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

                        baseR = Double(Int(round(r * 255)))
                        baseG = Double(Int(round(g * 255)))
                        baseB = Double(Int(round(b * 255)))

                        scanTemperatureValue = 0.5
                        scanSaturationValue = 0.5
                        scanBrightnessValue = 0.5
                    }
                    .padding(.horizontal)

                    TextField("Color Name", text: $colorName)
                        .font(.system(size: 18, weight: .medium))
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
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
                    Text("Pick or take a photo to extract the dominant color")
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

    // MARK: - Labels

    private func offsetLabel(_ value: Double, positive: String? = nil, negative: String? = nil) -> String {
        let offset = Int(round((value - 0.5) * 100))
        if offset == 0 { return "Neutral" }
        if offset > 0 {
            return positive.map { "+\(offset) \($0)" } ?? "+\(offset)"
        }
        return negative.map { "\(offset) \($0)" } ?? "\(offset)"
    }

    // MARK: - Actions

    private func extractDominantColor(from image: UIImage) {
        do {
            let rgb = try ImageColorExtractor.extractDominantRGB(from: image)

            baseR = rgb.r
            baseG = rgb.g
            baseB = rgb.b
            scanTemperatureValue = 0.5
            scanSaturationValue = 0.5
            scanBrightnessValue = 0.5
            hasExtractedColor = true

            let hex = String(format: "%02X%02X%02X", Int(round(rgb.r)), Int(round(rgb.g)), Int(round(rgb.b)))
            colorName = nameForHex(hex)
        } catch let error {
            ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
        }
    }

    private func autoFillName() {
        let raw = currentHEX.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard raw.count == 6, Color(hex: raw) != nil else { return }
        colorName = nameForHex(raw)
    }

    private func nameForHex(_ rawHex: String) -> String {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare("#\(rawHex)") == .orderedSame }) {
            return existing.name
        }
        return ColorNamer.name(forHex: rawHex)
    }

    private func createColor() {
        guard let (hex, color) = resolvedHexAndColor else {
            if inputMode == .pick { hexError = true }
            return
        }
        let name = colorName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            ToastManager.shared.show("Already exists as '\(existing.name)'", icon: "exclamationmark.circle.fill")
            return
        }

        let newColor = ColorViewModel(name: name, color: color, HEX: hex, usedInPalette: false)
        withAnimation {
            appData.colors.append(newColor)
        }
        dismiss()
    }
}

#Preview {
    NewColorView()
        .environmentObject(AppData())
}
