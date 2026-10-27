//
//  PalettePickSource.swift
//  Palettes
//
//  The add panel's Pick source, built from the dev branch's picker but
//  compact: a preview as tall as the palette strip, the name with the system
//  color wheel and a + beside it, and live-synced HEX and RGB fields. Editing
//  any one updates the others.
//

import SwiftUI

struct PalettePickSource: View {
    @Binding var color: Color
    @Binding var name: String
    let excludedHexes: Set<String>
    /// True while one of the text fields has the keyboard.
    @Binding var fieldFocused: Bool
    var onAdd: (PaletteColor) -> Void

    private enum Field: Hashable { case name, hex, r, g, b }

    @EnvironmentObject private var appData: AppData
    @FocusState private var focus: Field?
    /// The name for the current color, once the color settles.
    @State private var autoName = ""
    @State private var hexText = ""
    @State private var hexError = false
    @State private var rString = "128"
    @State private var gString = "128"
    @State private var bString = "128"
    /// Set while the fields are being written from the color, so their
    /// onChange handlers don't write back.
    @State private var isSyncing = false

    private var hex: String { ColorComposer.hexKey(color) }
    private var isDuplicate: Bool { excludedHexes.contains(hex.uppercased()) }
    private var canAdd: Bool { !hexError && !isDuplicate }

    var body: some View {
        FadingScrollView {
            VStack(spacing: 14) {
                preview
                    .frame(height: PaletteStripPreview.height)

                nameRow

                values
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { syncFields() }
        .onChange(of: color) { _, _ in
            if !isSyncing { syncFields() }
        }
        .task(id: hex) {
            // Names follow the color once it settles, not on every change.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            autoName = suggestedName(forHex: hex)
        }
        .onChange(of: focus) { _, field in fieldFocused = field != nil }
        .onDisappear { fieldFocused = false }
    }

    // MARK: - Preview

    private var preview: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            // Inside the swatch, so a notice never moves the picker.
            .overlay(alignment: .bottomTrailing) {
                Label("Already in this palette", systemImage: "info.circle")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: Capsule())
                    .padding(8)
                    .opacity(isDuplicate ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: isDuplicate)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isDuplicate ? "Already in this palette" : "Color preview, \(hex)")
    }

    // MARK: - Name, wheel, add

    /// The name takes what the color wheel and the + leave.
    private var nameRow: some View {
        HStack(spacing: 12) {
            TextField("", text: $name)
                .font(.system(size: 18, weight: .medium))
                .legiblePlaceholder(autoName.isEmpty ? "Color Name" : autoName, isEmpty: name.isEmpty)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .focused($focus, equals: .name)
                .onSubmit { focus = nil }
                .padding()
                .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                .accessibilityLabel("Color name")

            ColorPicker("Color Wheel", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.5)
                .frame(width: 44, height: 44)

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .glassButton(prominent: true)
            .buttonBorderShape(.circle)
            .disabled(!canAdd)
            .accessibilityLabel("Add Color")
        }
    }

    // MARK: - Values

    /// HEX, R, G and B in one compact row. A tap opens a field for typing;
    /// press and hold copies (HEX, or all three RGB values).
    private var values: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Values")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ValuesRow {
                HStack(spacing: 2) {
                    Text("#")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("808080", text: $hexText)
                        .font(.system(size: 15, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .hex)
                        .onChange(of: hexText) { _, newValue in
                            guard !isSyncing else { return }
                            updateColor(fromHex: newValue)
                        }
                        .accessibilityLabel("HEX")
                        .allowsHitTesting(focus == .hex)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .copyOrEdit(isEditing: focus == .hex, copy: copyHex, edit: { focus = .hex })
                // ValuesRow makes HEX a little wider than each channel.
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlass(.regular, in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(hexError ? Color.red : Color.clear, lineWidth: 1.5)
                )

                rgbField("R", text: $rString, field: .r)
                rgbField("G", text: $gString, field: .g)
                rgbField("B", text: $bString, field: .b)
            }

            if hexError {
                Text("Invalid HEX code. Use 6-character format like FF5D00.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text(ValuesHelp.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rgbField(_ label: String, text: Binding<String>, field: Field) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("0", text: text)
                .font(.system(size: 15, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($focus, equals: field)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { text.wrappedValue = filtered }
                    guard !isSyncing else { return }
                    updateColorFromRGB()
                }
                .accessibilityLabel(label)
                .allowsHitTesting(focus == field)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .copyOrEdit(isEditing: focus == field, copy: copyRGB, edit: { focus = field })
        .frame(maxWidth: .infinity)
        .liquidGlass(.regular, in: .rect(cornerRadius: 10))
    }

    private func copyHex() {
        copy("#\(hexText)", label: "Copied HEX")
    }

    private func copyRGB() {
        copy("\(rString), \(gString), \(bString)", label: "Copied RGB")
    }

    private func copy(_ value: String, label: String) {
        UIPasteboard.general.string = value
        ToastManager.shared.show(label, icon: "doc.on.doc.fill")
    }

    // MARK: - Sync

    /// Writes the HEX and RGB fields from the color.
    private func syncFields() {
        isSyncing = true
        let c = color.rgbComponents
        let r = Int(round(c.r)), g = Int(round(c.g)), b = Int(round(c.b))
        rString = "\(r)"
        gString = "\(g)"
        bString = "\(b)"
        let newHex = String(format: "%02X%02X%02X", r, g, b)
        if hexText != newHex { hexText = newHex }
        hexError = false
        // The fields' onChange handlers run after this update; let them see the flag.
        Task { @MainActor in isSyncing = false }
    }

    private func updateColor(fromHex text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard clean.count == 6, let newColor = Color(hex: clean) else {
            hexError = true
            return
        }
        hexError = false
        isSyncing = true
        color = newColor
        let c = newColor.rgbComponents
        rString = "\(Int(round(c.r)))"
        gString = "\(Int(round(c.g)))"
        bString = "\(Int(round(c.b)))"
        Task { @MainActor in isSyncing = false }
    }

    private func updateColorFromRGB() {
        guard let r = Int(rString), r <= 255,
              let g = Int(gString), g <= 255,
              let b = Int(bString), b <= 255 else { return }
        isSyncing = true
        color = Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        hexText = String(format: "%02X%02X%02X", r, g, b)
        hexError = false
        Task { @MainActor in isSyncing = false }
    }

    // MARK: - Add

    private func add() {
        guard canAdd else { return }
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = typed.isEmpty ? suggestedName(forHex: hex) : typed
        focus = nil
        onAdd(PaletteColor(color: color, hex: hex, name: resolved))
    }

    /// A saved color's own name first, then ColorNamer, as everywhere else.
    private func suggestedName(forHex hex: String) -> String {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            return existing.name
        }
        return ColorNamer.name(forHex: hex)
    }
}
