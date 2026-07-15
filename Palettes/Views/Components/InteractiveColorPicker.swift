import SwiftUI

enum ColorInputMode {
    case hex
    case rgb
    case combined
}

/// Color wheel with live-synced editable HEX and RGB fields.
/// All inputs are views of the same color: editing any one updates the others.
/// `.combined` (the default) shows both value rows; `.hex`/`.rgb` show one.
struct InteractiveColorPicker: View {
    var mode: ColorInputMode = .combined

    @Binding var colorValue: Color
    @Binding var internalName: String

    // Bindings to the parent's source of truth so the parent can validate & save
    @Binding var currentHEX: String
    @Binding var hexError: Bool

    // Internal state for RGB editing
    @State private var rString: String = "128"
    @State private var gString: String = "128"
    @State private var bString: String = "128"

    @State private var isUpdatingFromComponents = false

    var body: some View {
        VStack(spacing: 16) {
            // Live Preview
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorValue.gradient)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.top, 16)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))

            // Color Name Field
            TextField("Color Name", text: $internalName)
                .font(.system(size: 18, weight: .medium))
                .padding()
                .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)

            // The Color Wheel
            VStack(alignment: .leading, spacing: 4) {
                Text("Color Wheel")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                ColorPicker("Select Color", selection: $colorValue, supportsOpacity: false)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .scaleEffect(CGSize(width: 1.5, height: 1.5))
                    .padding(.vertical, 16)
                    .onChange(of: colorValue) { _, _ in
                        if !isUpdatingFromComponents {
                            syncComponentsToColor()
                        }
                    }
            }
            .padding(.horizontal)

            // Value Fields
            VStack(alignment: .leading, spacing: 12) {
                Text("Values")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                if mode != .rgb {
                HStack {
                    Text("HEX")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, alignment: .leading)

                    Text("#")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)

                    TextField("808080", text: $currentHEX)
                        .font(.system(size: 16, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: currentHEX) { _, newValue in
                            guard !isUpdatingFromComponents else { return }
                            hexError = false
                            updateColorFromHex(newValue)
                        }

                    Spacer()

                    Button {
                        copyToClipboard(currentHEX, label: "Copied HEX")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .liquidGlass(.regular, in: .rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hexError ? Color.red : Color.clear, lineWidth: 1.5)
                )
                .padding(.horizontal)

                if hexError {
                    Text("Invalid HEX code. Use 6-character format like FF5D00.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                }

                if mode != .hex {
                HStack(spacing: 12) {
                    rgbField(label: "R", text: $rString)
                    rgbField(label: "G", text: $gString)
                    rgbField(label: "B", text: $bString)

                    Button {
                        copyToClipboard("\(rString), \(gString), \(bString)", label: "Copied RGB")
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
                .padding(.horizontal)
                }
            }

            Spacer()
        }
        .onAppear {
            syncComponentsToColor()
        }
    }

    @ViewBuilder
    private func rgbField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("0", text: text)
                .font(.system(size: 16, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .onChange(of: text.wrappedValue) { _, newValue in
                    let filtered = newValue.filter { "0123456789".contains($0) }
                    if filtered != newValue {
                        text.wrappedValue = filtered
                    }
                    guard !isUpdatingFromComponents else { return }
                    updateColorFromRGB()
                }
        }
        .padding(12)
        .liquidGlass(.regular, in: .rect(cornerRadius: 12))
    }

    private func syncComponentsToColor() {
        isUpdatingFromComponents = true

        let c = colorValue.rgbComponents
        let rInt = Int(round(c.r))
        let gInt = Int(round(c.g))
        let bInt = Int(round(c.b))

        rString = "\(rInt)"
        gString = "\(gInt)"
        bString = "\(bInt)"

        // Only update currentHEX if it actually changed to prevent cursor jumping
        let newHex = String(format: "%02X%02X%02X", rInt, gInt, bInt)
        if currentHEX != newHex {
            currentHEX = newHex
        }

        isUpdatingFromComponents = false
    }

    private func updateColorFromHex(_ hex: String) {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanHex.count == 6 else {
            hexError = true
            return
        }
        if let newColor = Color(hex: cleanHex) {
            isUpdatingFromComponents = true
            colorValue = newColor

            let c = newColor.rgbComponents
            rString = "\(Int(round(c.r)))"
            gString = "\(Int(round(c.g)))"
            bString = "\(Int(round(c.b)))"

            isUpdatingFromComponents = false
        } else {
            hexError = true
        }
    }

    private func updateColorFromRGB() {
        guard let rVal = Int(rString), rVal <= 255,
              let gVal = Int(gString), gVal <= 255,
              let bVal = Int(bString), bVal <= 255 else { return }

        isUpdatingFromComponents = true
        let newColor = Color(red: Double(rVal) / 255, green: Double(gVal) / 255, blue: Double(bVal) / 255)
        colorValue = newColor

        currentHEX = String(format: "%02X%02X%02X", rVal, gVal, bVal)
        isUpdatingFromComponents = false
    }
}
