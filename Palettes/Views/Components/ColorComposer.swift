//
//  ColorComposer.swift
//  Palettes
//

import SwiftUI

/// The one color editor, shared by New Color, Edit Color and adding a color to
/// a palette. The color and its name stay pinned at the top as a compact swatch,
/// with the always-visible picker (Spectrum, Grid, RGB Sliders) right under it,
/// so every change is visible as you make it. Below, on a plain grouped
/// background, scroll liquid-glass cards: the Tag row (when the host offers
/// one), the Fine-tune sliders (Temperature / Saturation / Brightness) and the
/// HEX and RGB values.
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
    /// When set, a "Tag" card appears first in the scrolling part; tapping it
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

    /// The notice text last shown, so it can fade out without the row
    /// changing size or going blank first.
    @State private var shownNotice = ""

    private enum Origin {
        case adjustments, hex, rgb, outside
    }

    private var isRegular: Bool { horizontalSizeClass == .regular }

    /// Side by side when wide (iPad) or short (iPhone landscape), so the cards
    /// aren't squeezed under the pinned swatch and picker.
    private var usesTwoColumns: Bool { isRegular || verticalSizeClass == .compact }

    /// While a value field has the keyboard, the swatch shrinks and the picker
    /// steps aside so the fields stay in view.
    private var isEditingValues: Bool {
        guard let focusedField else { return false }
        return focusedField != .name
    }

    /// Swatch height and card position follow the header with a spring; with
    /// Reduce Motion they snap and only the picker fades.
    private var layoutAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    private var pickerAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0)
    }

    var body: some View {
        // The picker is drag-based, so it stays outside the cards' scroll view
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

                    cards
                }
            } else {
                VStack(spacing: 0) {
                    header
                    pickerPanel
                    cards
                }
                .animation(layoutAnimation, value: isEditingValues)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            swatch
            noticeRow
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    /// Always laid out (one footnote line), so a notice appearing or going
    /// away fades in place and never moves the picker below.
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

    private var cards: some View {
        ScrollView {
            // The container animates this scroll view's frame as the header
            // changes; the cards themselves must not animate with focus.
            VStack(alignment: .leading, spacing: 16) {
                if let tag {
                    tagCard(tag)
                        .transaction { $0.animation = nil }
                }
                adjustSection
                    .transaction { $0.animation = nil }
                valuesSection
                    .transaction { $0.animation = nil }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
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
                    title: "Temperature",
                    valueLabel: ColorAdjustment.offsetLabel(temperatureValue, positive: "warm", negative: "cool"),
                    leftLabel: "Cool",
                    rightLabel: "Warm",
                    value: adjustmentBinding($temperatureValue)
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
            }
            .padding(14)
            .liquidGlass(.regular, in: .rect(cornerRadius: 20))

            Text("Nudge the color warmer, richer or lighter.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var valuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Values")

            HStack {
                Text("HEX")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, alignment: .leading)
                    .accessibilityHidden(true)
                Text("#")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("FF5D00", text: hexBinding)
                    .font(.system(size: 16, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .hex)
                    .accessibilityLabel("HEX code")
            }
            .padding(12)
            .liquidGlass(.regular, in: .rect(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture { focusedField = .hex }

            HStack(spacing: 12) {
                channelField("R", text: $redText, field: .red, spoken: "Red")
                channelField("G", text: $greenText, field: .green, spoken: "Green")
                channelField("B", text: $blueText, field: .blue, spoken: "Blue")
            }

            if focusedField == .hex, hexText.count < 6 {
                Text("HEX codes have six characters, like FF5D00.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func channelField(_ label: String, text: Binding<String>, field: Field, spoken: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("0", text: channelBinding(text))
                .font(.system(size: 16, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focusedField, equals: field)
                .accessibilityLabel(spoken)
        }
        .padding(12)
        .liquidGlass(.regular, in: .rect(cornerRadius: 12))
        .contentShape(Rectangle())
        .onTapGesture { focusedField = field }
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
