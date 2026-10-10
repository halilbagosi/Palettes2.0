import SwiftUI

enum ColorInputMode {
    case hex
    case rgb
    case combined
}

/// The Pick surface: a name, hue/saturation/brightness sliders (with the system
/// picker's eyedropper and spectrum), and editable HEX and RGB values. All are
/// views of one color: editing any of them updates the rest.
/// `.combined` (the default) shows both value rows; `.hex`/`.rgb` show one.
struct InteractiveColorPicker: View {
    var mode: ColorInputMode = .combined
    /// Swatch beside the name; off when the host shows its own large preview.
    var showsSwatch: Bool = true

    @Binding var colorValue: Color
    @Binding var internalName: String

    // Bindings to the parent's source of truth so the parent can validate & save
    @Binding var currentHEX: String
    @Binding var hexError: Bool

    @State private var rString: String = "128"
    @State private var gString: String = "128"
    @State private var bString: String = "128"

    var body: some View {
        VStack(spacing: 16) {
            ColorNameField(color: showsSwatch ? colorValue : nil, name: $internalName)

            HSBSlidersCard(color: colorValue) { newColor in
                colorValue = newColor
                syncFields(from: newColor)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                SheetSectionHeader(title: "Values")
                valuesCard
            }
        }
        .onAppear {
            syncFields(from: colorValue)
        }
    }

    // MARK: - Values

    private var valuesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mode != .rgb {
                hexRow
            }

            if mode != .hex {
                HStack(spacing: 10) {
                    rgbField(label: "R", text: $rString)
                    rgbField(label: "G", text: $gString)
                    rgbField(label: "B", text: $bString)
                }
            }

            if hexError {
                Text("Invalid HEX code. Use 6-character format like FF5D00.")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if mode != .rgb, !currentHEX.isEmpty, currentHEX.count < 6 {
                Text("HEX codes have six characters, like FF5D00.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .liquidGlass(.regular, in: .rect(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var hexRow: some View {
        HStack(spacing: 8) {
            Text("HEX")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            Text("#")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)

            TextField("808080", text: hexBinding)
                .font(.system(size: 16, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            Button {
                copyToClipboard("#\(currentHEX)", label: "Copied HEX")
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(currentHEX.count != 6)
            .accessibilityLabel("Copy HEX")
        }
        .padding(12)
        .background(fieldBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(hexError ? Color.red : Color.clear, lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func rgbField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("0", text: Binding(
                get: { text.wrappedValue },
                set: { newValue in
                    text.wrappedValue = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(3))
                    updateColorFromRGB()
                }
            ))
            .font(.system(size: 16, design: .monospaced))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(fieldBackground)
    }

    /// Fields sit inside a glass card, so they get a quiet fill rather than
    /// glass of their own.
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.06))
    }

    // MARK: - Sync

    /// Typing filters to hex digits (so a pasted "#ff5d00" just works) and
    /// applies the color once all six are in.
    private var hexBinding: Binding<String> {
        Binding(
            get: { currentHEX },
            set: { newValue in
                let cleaned = String(newValue.uppercased().filter { $0.isHexDigit }.prefix(6))
                currentHEX = cleaned
                hexError = false
                guard cleaned.count == 6, let newColor = Color(hex: cleaned) else { return }
                colorValue = newColor
                let c = newColor.rgbComponents
                rString = "\(Self.channel(c.r))"
                gString = "\(Self.channel(c.g))"
                bString = "\(Self.channel(c.b))"
            }
        )
    }

    private func updateColorFromRGB() {
        guard let rVal = Int(rString), rVal <= 255,
              let gVal = Int(gString), gVal <= 255,
              let bVal = Int(bString), bVal <= 255 else { return }

        colorValue = Color(red: Double(rVal) / 255, green: Double(gVal) / 255, blue: Double(bVal) / 255)
        currentHEX = String(format: "%02X%02X%02X", rVal, gVal, bVal)
        hexError = false
    }

    private func syncFields(from color: Color) {
        let c = color.rgbComponents
        let r = Self.channel(c.r)
        let g = Self.channel(c.g)
        let b = Self.channel(c.b)

        rString = "\(r)"
        gString = "\(g)"
        bString = "\(b)"

        // Only write on change to keep the cursor where it is.
        let newHex = String(format: "%02X%02X%02X", r, g, b)
        if currentHEX != newHex {
            currentHEX = newHex
        }
        hexError = false
    }

    /// 0–255 channel, clamped: wide-gamut picks can land outside sRGB.
    private static func channel(_ value: Double) -> Int {
        Int(round(min(max(value, 0), 255)))
    }
}
