//
//  ColorComposer.swift
//  Palettes
//

import SwiftUI
import UIKit
import PhotosUI

/// The one color editor, shared by New Color, Edit Color and adding a color to
/// a palette. The color stays pinned at the top as a plain swatch, with the
/// name on glass under it and the system color wheel (and, for new colors, a
/// photo button) beside the name. Below scroll liquid-glass cards: the photo
/// (once one is picked), the Tag row (when the host offers one), the Fine-tune
/// sliders (Hue / Saturation / Brightness / Temperature) and the HEX and RGB
/// values in one compact row (New Color puts the values first).
///
/// Hosts own `color` and `name` and supply the navigation title and toolbar.
struct ColorComposer: View {
    @Binding var color: Color
    @Binding var name: String
    /// Edit Color: the sheet is tinted with the color.
    var tinted: Bool = false
    /// New Color: a photo button beside the color wheel; a picked photo shows
    /// above the sliders and its colors can be picked off it.
    var allowsPhoto: Bool = false
    /// New colors: the name follows the color until the user types one of
    /// their own. Existing colors keep their name.
    var namesFollowColor: Bool = false
    /// A short status under the name, e.g. "Already in this palette".
    var notice: String? = nil
    /// When set, a "Tag" card appears first in the scrolling part; tapping it
    /// calls `onTap` so the host can present its own tag picker.
    var tag: (role: String?, onTap: () -> Void)? = nil

    @EnvironmentObject private var appData: AppData
    @ScaledMetric(relativeTo: .title3) private var swatchHeight: CGFloat = 96
    @ScaledMetric(relativeTo: .title3) private var shrunkSwatchHeight: CGFloat = 64
    /// Everything in the header below the swatch (spacing 6 + 6, the name row
    /// ≈ 54, the notice line ≈ 16, padding 8 + 8 = 98, plus 6 margin = 104), and the least room the
    /// controls need, for `SheetLayout`'s "too short to stack" test.
    @ScaledMetric(relativeTo: .title3) private var nameRowHeight: CGFloat = 104
    @ScaledMetric(relativeTo: .body) private var minControlsHeight: CGFloat = 220
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private enum Field: Hashable {
        case name, hex, red, green, blue
    }
    @FocusState private var focusedField: Field?
    /// The picked photo and where its color was last picked.
    @StateObject private var scanSession = ScanSession()
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var cameraImage: UIImage?
    @State private var didCapture = false
    /// The full-screen photo picker; a fresh value per request, so a retry
    /// always presents even if an earlier presentation was refused.
    @State private var photoPicker: PhotoPickerRequest?
    /// The camera cover is up or still dismissing; a second cover waits for it.
    @State private var cameraCoverActive = false
    /// A new photo is ready to open in the picker once the camera has gone.
    @State private var pickerWaitingForCamera = false

    private struct PhotoPickerRequest: Identifiable {
        let id = UUID()
    }

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    // Tuning sliders: offsets from `base*` (0…1, 0.5 neutral). Any other
    // change makes the new color the base and centers them again.
    @State private var hueValue: Double = 0.5
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

    /// The notice text last shown, so it can fade out without the row
    /// changing size or going blank first.
    @State private var shownNotice = ""

    private enum Origin {
        case adjustments, hex, rgb, outside
    }

    /// Stacked needs the swatch, the name row and a usable slice of controls.
    private var minStackedHeight: CGFloat { swatchHeight + nameRowHeight + minControlsHeight }

    /// While a value field has the keyboard, the swatch shrinks so the fields
    /// stay in view.
    private var isEditingValues: Bool {
        guard let focusedField else { return false }
        return focusedField != .name
    }

    /// Swatch height and card position follow the header with a spring; with
    /// Reduce Motion they snap.
    private var layoutAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    var body: some View {
        SheetLayoutReader(minStackedHeight: minStackedHeight) { layout, fold in
            // A fold always wins: a crease across stacked controls would
            // leave them scrolling over it.
            if let fold {
                FoldSplit(fold: fold) {
                    header(fillsHeight: true)
                } controls: {
                    cards
                }
            } else {
                switch layout {
                case .stacked:
                    VStack(spacing: 0) {
                        header(fillsHeight: false)
                        cards
                    }
                    .animation(layoutAnimation, value: isEditingValues)
                case .split:
                    HStack(spacing: 0) {
                        header(fillsHeight: true)
                            .frame(maxWidth: .infinity)
                        cards
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(background.ignoresSafeArea())
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
            shownNotice = notice ?? ""
            apply(color, from: .outside)
        }
        .onChange(of: Self.hexKey(color)) { _, hex in
            if hex != syncedHex { apply(color, from: .outside) }
        }
        .onChange(of: focusedField) { previous, _ in
            restoreIncompleteField(previous)
        }
        .onChange(of: notice) { _, new in
            if let new { shownNotice = new }
        }
        .modifier(PhotoSources(
            enabled: allowsPhoto,
            showCamera: $showCamera,
            showLibrary: $showLibrary,
            photosPickerItem: $photosPickerItem,
            cameraImage: $cameraImage,
            didCapture: $didCapture,
            session: scanSession,
            onCameraPresented: { cameraCoverActive = true },
            onCameraDismissed: {
                cameraCoverActive = false
                if pickerWaitingForCamera {
                    pickerWaitingForCamera = false
                    photoPicker = PhotoPickerRequest()
                }
            }
        ))
        .fullScreenCover(item: $photoPicker) { _ in
            if let image = scanSession.image {
                PhotoColorPickerView(
                    image: image,
                    initialPoint: scanSession.point,
                    adaptiveStage: true,
                    onUse: { _ in },
                    onUseSample: { rgb, point in
                        if let point { scanSession.sample(at: point) }
                        apply(ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b), from: .outside)
                    }
                )
            }
        }
        // A new photo opens straight into the full-screen picker, its marker
        // in the photo's center; Pick later reopens it where it was left.
        .onChange(of: scanSession.needsDelivery) { _, needs in
            guard needs else { return }
            scanSession.needsDelivery = false
            // The picker starts in the photo's center.
            scanSession.sample(at: CGPoint(x: 0.5, y: 0.5))
            if let picked = scanSession.sampledColor { apply(picked, from: .outside) }
            if cameraCoverActive { pickerWaitingForCamera = true } else { photoPicker = PhotoPickerRequest() }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if tinted {
            // Dev's Edit Color tint: the color at the top, fading to a
            // near-white (or near-black) of the same hue.
            LinearGradient(colors: [color.opacity(0.8), tintEnd], startPoint: .top, endPoint: .bottom)
        } else {
            Color(.systemGroupedBackground)
        }
    }

    private var tintEnd: Color {
        let (h, s, _) = color.hsbComponents
        return colorScheme == .dark
            ? Color(hue: h, saturation: s, brightness: 0.08)
            : Color(hue: h, saturation: s * 0.08, brightness: 0.97)
    }

    // MARK: - Header

    private func header(fillsHeight: Bool) -> some View {
        VStack(spacing: 6) {
            swatch(fillsHeight: fillsHeight)
            nameRow
                .padding(.top, 6)
            noticeRow
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    /// Always laid out (one footnote line), so a notice appearing or going
    /// away fades in place and never moves the cards below.
    private var noticeRow: some View {
        Label(shownNotice.isEmpty ? " " : shownNotice, systemImage: "info.circle")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .opacity(notice == nil ? 0 : 1)
            .animation(.easeOut(duration: 0.2), value: notice)
            .accessibilityHidden(notice == nil)
    }

    /// Just the color: the name and HEX have their own fields.
    /// Stacked: a fixed-height band that shrinks while a value field is
    /// focused. Split: fills the whole height of its half.
    private func swatch(fillsHeight: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return shape
            .fill(color.gradient)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: fillsHeight ? .infinity : nil)
            .frame(height: fillsHeight ? nil : (isEditingValues ? shrunkSwatchHeight : swatchHeight))
            .overlay(shape.stroke(Color.primary.opacity(0.1), lineWidth: 1))
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
            .contextMenu {
                Button("Copy HEX", systemImage: "doc.on.doc") {
                    copyToClipboard(syncedHex, label: "Copied HEX")
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Color preview, \(syncedHex)")
            .accessibilityAction(named: "Copy HEX") {
                copyToClipboard(syncedHex, label: "Copied HEX")
            }
    }

    /// The Pick tab's name row: the name on glass, the color wheel beside it
    /// and, for new colors, the photo button.
    private var nameRow: some View {
        HStack(spacing: 12) {
            TextField("Name", text: nameBinding)
                .font(.system(size: 18, weight: .medium))
                .submitLabel(.done)
                .focused($focusedField, equals: .name)
                .padding()
                .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                .accessibilityLabel("Color name")

            ColorPicker("Color Wheel", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.5)
                .frame(width: 44, height: 44)

            if allowsPhoto {
                photoMenu
            }
        }
    }

    /// Generate's photo button, as a circle: take or choose a photo.
    private var photoMenu: some View {
        Menu {
            if Self.cameraAvailable {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera")
                }
            }
            // A PhotosPicker nested in a Menu never presents; the item flips
            // a flag that drives `.photosPicker(isPresented:)`.
            Button { showLibrary = true } label: {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .liquidGlass(.interactive, in: .circle)
        }
        .accessibilityLabel(scanSession.image == nil ? "Add Photo" : "Replace Photo")
    }

    // MARK: - Photo

    /// The picked photo, compact, with Remove and Pick Colors under it.
    private var photoSection: some View {
        PhotoPreview(
            image: scanSession.image,
            isLoading: scanSession.isLoading,
            height: 150,
            canPick: scanSession.image != nil && !scanSession.isLoading,
            onPick: { photoPicker = PhotoPickerRequest() },
            onRemove: {
                withAnimation(layoutAnimation) { scanSession.clear() }
            }
        )
    }

    private var cards: some View {
        FadingScrollView {
            // The container animates this scroll view's frame as the header
            // changes; the cards themselves must not animate with focus.
            VStack(alignment: .leading, spacing: 16) {
                // New Color: the values right under the name.
                if allowsPhoto {
                    valuesSection
                        .transaction { $0.animation = nil }
                }
                if allowsPhoto, scanSession.image != nil || scanSession.isLoading {
                    photoSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if let tag {
                    tagCard(tag)
                        .transaction { $0.animation = nil }
                }
                adjustSection
                    .transaction { $0.animation = nil }
                if !allowsPhoto {
                    valuesSection
                        .transaction { $0.animation = nil }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .animation(layoutAnimation, value: scanSession.image != nil || scanSession.isLoading)
        }
        .scrollDismissesKeyboard(.interactively)
        .softScrollEdge()
    }

    // MARK: - Cards

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func tagCard(_ tag: (role: String?, onTap: () -> Void)) -> some View {
        Button(action: tag.onTap) {
            HStack {
                Text("Tag")
                Spacer()
                Text(tag.role ?? "None")
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .liquidGlass(.regular, in: .rect(cornerRadius: 16))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var adjustSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Fine-tune")

            VStack(spacing: 16) {
                AdjustmentSlider(
                    title: "Hue",
                    valueLabel: ColorAdjustment.hueLabel(hueValue),
                    leftLabel: "−180°",
                    rightLabel: "+180°",
                    value: adjustmentBinding($hueValue)
                )
                AdjustmentSlider(
                    title: "Saturation",
                    valueLabel: ColorAdjustment.offsetLabel(saturationValue),
                    leftLabel: "Muted",
                    rightLabel: "Vivid",
                    value: adjustmentBinding($saturationValue)
                )
                AdjustmentSlider(
                    title: "Brightness",
                    valueLabel: ColorAdjustment.offsetLabel(brightnessValue),
                    leftLabel: "Dark",
                    rightLabel: "Light",
                    value: adjustmentBinding($brightnessValue)
                )
                AdjustmentSlider(
                    title: "Temperature",
                    valueLabel: ColorAdjustment.offsetLabel(temperatureValue, positive: "warm", negative: "cool"),
                    leftLabel: "Cool",
                    rightLabel: "Warm",
                    value: adjustmentBinding($temperatureValue)
                )
            }
            .padding(14)
            .liquidGlass(.regular, in: .rect(cornerRadius: 20))

            Text("Turn the hue, or nudge the color richer, lighter or warmer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// The Pick tab's values: HEX, R, G and B in one compact row. A tap
    /// opens a field for typing; press and hold copies (HEX, or all three
    /// RGB values).
    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Values")

            ValuesRow {
                HStack(spacing: 2) {
                    Text("#")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("FF5D00", text: hexBinding)
                        .font(.system(size: 15, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .hex)
                        .accessibilityLabel("HEX code")
                        .allowsHitTesting(focusedField == .hex)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .copyOrEdit(isEditing: focusedField == .hex, copy: copyHex, edit: { focusedField = .hex })
                // ValuesRow makes HEX a little wider than each channel.
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(.regular, in: .rect(cornerRadius: 10))

                compactChannel("R", text: $redText, field: .red, spoken: "Red")
                compactChannel("G", text: $greenText, field: .green, spoken: "Green")
                compactChannel("B", text: $blueText, field: .blue, spoken: "Blue")
            }

            Text(focusedField == .hex && hexText.count < 6
                 ? "HEX codes have six characters, like FF5D00."
                 : ValuesHelp.text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func compactChannel(_ label: String, text: Binding<String>, field: Field, spoken: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("0", text: channelBinding(text))
                .font(.system(size: 15, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
                .accessibilityLabel(spoken)
                .allowsHitTesting(focusedField == field)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .copyOrEdit(isEditing: focusedField == field, copy: copyRGB, edit: { focusedField = field })
        .frame(maxWidth: .infinity)
        .liquidGlass(.regular, in: .rect(cornerRadius: 10))
    }

    private func copyHex() {
        copyToClipboard(syncedHex, label: "Copied HEX")
    }

    private func copyRGB() {
        copyToClipboard("\(redText), \(greenText), \(blueText)", label: "Copied RGB")
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

    /// Moves a tuning slider and applies all four offsets to the base color.
    private func adjustmentBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = newValue
                let c = ColorAdjustment.apply(
                    baseR: baseR, baseG: baseG, baseB: baseB,
                    hue: hueValue,
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
        hueValue = 0.5
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

/// New Color's photo sources: the library picker and the camera, loading
/// into the scan session. Does nothing when photos aren't offered.
private struct PhotoSources: ViewModifier {
    let enabled: Bool
    @Binding var showCamera: Bool
    @Binding var showLibrary: Bool
    @Binding var photosPickerItem: PhotosPickerItem?
    @Binding var cameraImage: UIImage?
    @Binding var didCapture: Bool
    let session: ScanSession
    var onCameraPresented: () -> Void = {}
    var onCameraDismissed: () -> Void = {}

    func body(content: Content) -> some View {
        if enabled {
            content
                .photosPicker(isPresented: $showLibrary, selection: $photosPickerItem, matching: .images)
                .fullScreenCover(isPresented: $showCamera, onDismiss: onCameraDismissed) {
                    CameraPicker(image: $cameraImage, didCapture: $didCapture, isPresented: $showCamera)
                }
                .onChange(of: showCamera) { _, presented in
                    if presented { onCameraPresented() }
                }
                .onChange(of: photosPickerItem) { _, item in
                    guard let item else { return }
                    photosPickerItem = nil
                    session.load(item: item)
                }
                .onChange(of: didCapture) { _, captured in
                    guard captured else { return }
                    didCapture = false
                    if let photo = cameraImage { session.load(image: photo) }
                    cameraImage = nil
                }
        } else {
            content
        }
    }
}
