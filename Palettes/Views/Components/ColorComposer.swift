//
//  ColorComposer.swift
//  Palettes
//

import SwiftUI
import PhotosUI

/// The one color editor, shared by New Color, Edit Color and adding a color to
/// a palette. The color and its name stay pinned at the top as a compact swatch,
/// with the always-visible picker (Spectrum, Grid, RGB Sliders) right under it,
/// so every change is visible as you make it. Below, in a standard grouped
/// list, scroll the Fine-tune sliders (Temperature / Saturation / Brightness)
/// and the HEX and RGB values. The swatch's eyedropper menu opens the photo
/// sampler (Choose Photo, Take Photo) to pick an exact spot.
///
/// Hosts own `color` and `name` and supply the navigation title and toolbar.
struct ColorComposer: View {
    @Binding var color: Color
    @Binding var name: String
    /// New colors: the name follows the color until the user types one of
    /// their own. Existing colors keep their name.
    var namesFollowColor: Bool = false
    /// A short status under the name, e.g. "Already in this palette".
    var notice: String? = nil
    /// When set, a "Tag" row appears first in the scrolling part; tapping it
    /// calls `onTap` so the host can present its own tag picker.
    var tag: (role: String?, onTap: () -> Void)? = nil

    @EnvironmentObject private var appData: AppData
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @ScaledMetric(relativeTo: .title3) private var swatchHeight: CGFloat = 96
    @ScaledMetric(relativeTo: .title3) private var shrunkSwatchHeight: CGFloat = 64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field: Hashable {
        case name, hex, red, green, blue
    }
    @FocusState private var focusedField: Field?

    // Tuning sliders: offsets from `base*` (0…1, 0.5 neutral). Any other
    // change makes the new color the base and centers them again.
    @State private var temperatureValue: Double = 0.5
    @State private var saturationValue: Double = 0.5
    @State private var brightnessValue: Double = 0.5
    @State private var baseR: Double = 128
    @State private var baseG: Double = 128
    @State private var baseB: Double = 128
    @State private var hexText = ""
    @State private var redText = ""
    @State private var greenText = ""
    @State private var blueText = ""
    /// "#RRGGBB" of the color the controls last showed, so the editor's own
    /// writes coming back through `color` aren't applied twice.
    @State private var syncedHex = ""
    @State private var nameIsCustom = false
    @State private var didAppear = false

    // Photo sampling
    @State private var showPhotoLibrary = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCameraCapture = false
    @State private var sampling: SampleSource?

    private struct SampleSource: Identifiable {
        let id = UUID()
        let image: UIImage
        let seed: (r: Double, g: Double, b: Double)?
    }

    private enum Origin {
        case adjustments, hex, rgb, outside
    }

    // isSourceTypeAvailable(.camera) probes capture hardware and is slow.
    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    private var isRegular: Bool { horizontalSizeClass == .regular }

    /// Side by side when wide (iPad) or short (iPhone landscape), so the Form
    /// isn't squeezed under the pinned swatch and picker.
    private var usesTwoColumns: Bool { isRegular || verticalSizeClass == .compact }

    /// While a value field has the keyboard, the swatch shrinks and the picker
    /// steps aside so the fields stay in view.
    private var isEditingValues: Bool {
        guard let focusedField else { return false }
        return focusedField != .name
    }

    /// Swatch height and Form position follow the header with a spring; with
    /// Reduce Motion they snap and only the picker fades.
    private var layoutAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    private var pickerAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
    }

    var body: some View {
        // The picker is drag-based, so it stays outside the Form's scroll view
        // in both layouts.
        Group {
            if usesTwoColumns {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 0) {
                        header
                        pickerPanel
                    }
                    .frame(maxWidth: 380)
                    .animation(layoutAnimation, value: isEditingValues)

                    form
                }
            } else {
                VStack(spacing: 0) {
                    header
                    pickerPanel
                    form
                }
                .animation(layoutAnimation, value: isEditingValues)
            }
        }
        .background(ColorWashBackground(color: color))
        .toolbar {
            // The number pad has no return key: give every field a way out.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            nameIsCustom = !namesFollowColor || !name.isEmpty
            apply(color, from: .outside)
        }
        .onChange(of: Self.hexKey(color)) { _, hex in
            if hex != syncedHex { apply(color, from: .outside) }
        }
        .onChange(of: focusedField) { previous, _ in
            restoreIncompleteField(previous)
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            loadPhoto(item)
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: {
            // Present the sampler only once the camera has fully gone.
            if let image = cameraImage {
                cameraImage = nil
                beginSampling(image)
            }
        }) {
            CameraPicker(image: $cameraImage, didCapture: $didCameraCapture, isPresented: $showCamera)
        }
        .fullScreenCover(item: $sampling) { source in
            PhotoColorPickerView(
                image: source.image,
                initialRGB: source.seed,
                onUse: { rgb in
                    apply(ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b), from: .outside)
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            swatch

            if let notice {
                Label(notice, systemImage: "info.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.easeOut(duration: 0.2), value: notice)
    }

    private var swatch: some View {
        let ink = color.legibleInk
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            TextField(
                "Name",
                text: nameBinding,
                prompt: Text("Name").foregroundStyle(ink.opacity(0.55))
            )
            .font(.title3.weight(.semibold))
            .foregroundStyle(ink)
            .tint(ink)
            .submitLabel(.done)
            .focused($focusedField, equals: .name)
            .padding(.trailing, 46)   // clear of the eyedropper
            .accessibilityLabel("Color name")

            if !isEditingValues {
                Text(syncedHex)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(ink.opacity(0.7))
                    .accessibilityLabel("Color preview, \(syncedHex)")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(
            maxWidth: .infinity,
            minHeight: isEditingValues ? shrunkSwatchHeight : swatchHeight,
            alignment: .bottomLeading
        )
        .background(shape.fill(color.gradient))
        .overlay(shape.stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            samplePhotoMenu
                .padding(10)
        }
        .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
        .contextMenu {
            Button("Copy HEX", systemImage: "doc.on.doc") {
                copyToClipboard(syncedHex, label: "Copied HEX")
            }
        }
        .accessibilityAction(named: "Copy HEX") {
            copyToClipboard(syncedHex, label: "Copied HEX")
        }
    }

    private var samplePhotoMenu: some View {
        Menu {
            Button("Choose Photo", systemImage: "photo.on.rectangle") {
                showPhotoLibrary = true
            }
            if Self.cameraAvailable {
                Button("Take Photo", systemImage: "camera") {
                    showCamera = true
                }
            }
        } label: {
            Image(systemName: "eyedropper")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("Sample a Photo")
    }

    private var pickerPanel: some View {
        Group {
            if !isEditingValues {
                ColorPickerPanel(
                    color: $color,
                    compact: !isRegular,
                    onPick: { apply($0, from: .outside) }
                )
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
        }
        .animation(pickerAnimation, value: isEditingValues)
    }

    private var form: some View {
        Form {
            // The container animates the Form's frame as the header changes;
            // its contents (e.g. the HEX footer) must not animate with focus.
            if let tag {
                tagSection(tag)
                    .transaction { $0.animation = nil }
            }
            adjustSection
                .transaction { $0.animation = nil }
            valuesSection
                .transaction { $0.animation = nil }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .softScrollEdge()
    }

    // MARK: - Sections

    private func tagSection(_ tag: (role: String?, onTap: () -> Void)) -> some View {
        Section {
            Button(action: tag.onTap) {
                HStack {
                    LabeledContent("Tag") {
                        Text(tag.role ?? "None")
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var adjustSection: some View {
        Section {
            AdjustmentSlider(
                title: "Temperature",
                valueLabel: ColorAdjustment.offsetLabel(temperatureValue, positive: "warm", negative: "cool"),
                leftLabel: "Cool",
                rightLabel: "Warm",
                value: adjustmentBinding($temperatureValue)
            )
            .padding(.vertical, 4)

            AdjustmentSlider(
                title: "Saturation",
                valueLabel: ColorAdjustment.offsetLabel(saturationValue),
                leftLabel: "Muted",
                rightLabel: "Vivid",
                value: adjustmentBinding($saturationValue)
            )
            .padding(.vertical, 4)

            AdjustmentSlider(
                title: "Brightness",
                valueLabel: ColorAdjustment.offsetLabel(brightnessValue),
                leftLabel: "Dark",
                rightLabel: "Light",
                value: adjustmentBinding($brightnessValue)
            )
            .padding(.vertical, 4)
        } header: {
            Text("Fine-tune")
        } footer: {
            Text("Nudge the color warmer, richer or lighter.")
        }
    }

    private var valuesSection: some View {
        Section {
            LabeledContent("HEX") {
                HStack(spacing: 4) {
                    Text("#")
                        .foregroundStyle(.secondary)
                    TextField("FF5D00", text: hexBinding)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .hex)
                        .frame(width: 92)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityLabel("HEX code")
                }
                .font(.body.monospaced())
            }

            LabeledContent("RGB") {
                HStack(spacing: 6) {
                    channelField("R", text: $redText, field: .red, spoken: "Red")
                    channelField("G", text: $greenText, field: .green, spoken: "Green")
                    channelField("B", text: $blueText, field: .blue, spoken: "Blue")
                }
                .font(.body.monospaced())
            }
        } header: {
            Text("Values")
        } footer: {
            if focusedField == .hex, hexText.count < 6 {
                Text("HEX codes have six characters, like FF5D00.")
            }
        }
    }

    private func channelField(_ placeholder: String, text: Binding<String>, field: Field, spoken: String) -> some View {
        TextField(placeholder, text: channelBinding(text))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .focused($focusedField, equals: field)
            .frame(width: 48)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(spoken)
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding(
            get: { name },
            set: { newValue in
                name = newValue
                // Typing makes the name theirs; clearing it hands it back.
                nameIsCustom = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
            }
        )
    }

    /// Moves a tuning slider and applies all three offsets to the base color.
    private func adjustmentBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                let c = ColorAdjustment.apply(
                    baseR: baseR, baseG: baseG, baseB: baseB,
                    temperature: temperatureValue,
                    saturation: saturationValue,
                    brightness: brightnessValue
                )
                apply(ColorAdjustment.color(r: c.r, g: c.g, b: c.b), from: .adjustments)
            }
        )
    }

    /// Keeps hex digits only, so a pasted "#ff5d00" just works, and applies
    /// the color once all six are in.
    private var hexBinding: Binding<String> {
        Binding(
            get: { hexText },
            set: { newValue in
                let cleaned = String(newValue.uppercased().filter { $0.isHexDigit }.prefix(6))
                hexText = cleaned
                if cleaned.count == 6, let newColor = Color(hex: cleaned) {
                    apply(newColor, from: .hex)
                }
            }
        )
    }

    private func channelBinding(_ text: Binding<String>) -> Binding<String> {
        Binding(
            get: { text.wrappedValue },
            set: { newValue in
                text.wrappedValue = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(3))
                guard let r = Int(redText), let g = Int(greenText), let b = Int(blueText),
                      r <= 255, g <= 255, b <= 255 else { return }
                apply(Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255), from: .rgb)
            }
        )
    }

    // MARK: - Sync

    /// Makes `newColor` the color and brings every other control in line,
    /// leaving alone the control the change came from.
    private func apply(_ newColor: Color, from origin: Origin) {
        let rgb = Self.channels(newColor)
        let raw = String(format: "%02X%02X%02X", rgb.r, rgb.g, rgb.b)
        syncedHex = "#\(raw)"

        if origin != .hex { hexText = raw }
        if origin != .rgb {
            redText = "\(rgb.r)"
            greenText = "\(rgb.g)"
            blueText = "\(rgb.b)"
        }
        if origin != .adjustments { resetAdjustments(to: rgb) }

        color = newColor

        if namesFollowColor, !nameIsCustom {
            name = suggestedName(forRawHex: raw)
        }
    }

    /// Makes the color the sliders tune from, with every slider centered.
    private func resetAdjustments(to rgb: (r: Int, g: Int, b: Int)) {
        baseR = Double(rgb.r)
        baseG = Double(rgb.g)
        baseB = Double(rgb.b)
        temperatureValue = 0.5
        saturationValue = 0.5
        brightnessValue = 0.5
    }

    /// Leaving a half-typed value puts back the color's real one.
    private func restoreIncompleteField(_ field: Field?) {
        guard let field else { return }
        let rgb = Self.channels(color)
        switch field {
        case .hex where hexText.count != 6:
            hexText = String(syncedHex.dropFirst())
        case .red where Int(redText).map({ $0 > 255 }) ?? true:
            redText = "\(rgb.r)"
        case .green where Int(greenText).map({ $0 > 255 }) ?? true:
            greenText = "\(rgb.g)"
        case .blue where Int(blueText).map({ $0 > 255 }) ?? true:
            blueText = "\(rgb.b)"
        default:
            break
        }
    }

    /// Existing-color lookup first, then ColorNamer — identical naming across all sheets.
    private func suggestedName(forRawHex raw: String) -> String {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare("#\(raw)") == .orderedSame }) {
            return existing.name
        }
        return ColorNamer.name(forHex: raw)
    }

    // MARK: - Photo

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            photoItem = nil   // so the same photo can be chosen again
            guard let data, let image = UIImage(data: data) else {
                ToastManager.shared.show("Couldn't open that photo", icon: "exclamationmark.triangle.fill")
                return
            }
            // Let the photo picker finish dismissing before covering the screen.
            try? await Task.sleep(for: .milliseconds(300))
            beginSampling(image)
        }
    }

    /// Opens the sampler on the photo, seeded with its main color so Use works
    /// straight away.
    private func beginSampling(_ image: UIImage) {
        let seed = try? ImageColorExtractor.extractDominantRGB(from: image)
        sampling = SampleSource(image: image, seed: seed)
    }

    // MARK: - Helpers

    /// "#RRGGBB" for a color, channels clamped to sRGB (wide-gamut picks can
    /// land outside it).
    static func hexKey(_ color: Color) -> String {
        let rgb = channels(color)
        return String(format: "#%02X%02X%02X", rgb.r, rgb.g, rgb.b)
    }

    private static func channels(_ color: Color) -> (r: Int, g: Int, b: Int) {
        let c = color.rgbComponents
        return (clamp(c.r), clamp(c.g), clamp(c.b))
    }

    private static func clamp(_ value: Double) -> Int {
        Int(round(min(max(value, 0), 255)))
    }
}
