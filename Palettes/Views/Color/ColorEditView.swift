import SwiftUI

struct ColorEditView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appData: AppData
    
    // Original bindings
    @Binding var colorName: String
    @Binding var hexCode: String
    @Binding var colorValue: Color
    
    var promptOnNameMatch: Bool = false
    var onSaveWithAction: ((_ isOverwrite: Bool) -> Void)? = nil
    var onSave: () -> Void = {}
    
    // Local editable states to allow user modification before saving
    @State private var internalName: String = ""
    @State private var internalHex: String = ""
    @State private var internalColorValue: Color = .clear
    @State private var originalName: String = ""
    @State private var originalHex: String = ""
    @State private var showOverwriteAlert = false
    
    // Components of RGB for text fields
    @State private var rString: String = "255"
    @State private var gString: String = "255"
    @State private var bString: String = "255"
    
    // Flag to prevent cyclic updates between color picker and text fields
    @State private var isUpdatingFromHexOrRGB = false
    @State private var isUpdatingFromSliders = false
    
    // Slider state
    @State private var temperatureValue: Double = 0.5
    @State private var saturationValue: Double = 0.5
    @State private var brightnessValue: Double = 0.5
    @State private var baseR: Double = 0
    @State private var baseG: Double = 0
    @State private var baseB: Double = 0
    
    // Error tracking
    @State private var hexError = false
    
    // Gradient end color matched from ColorDetailView logic
    private var gradientEnd: Color {
        let (h, s, _) = internalColorValue.hsbComponents
        if colorScheme == .dark {
            return Color(hue: h, saturation: s, brightness: 0.08)
        } else {
            return Color(hue: h, saturation: s * 0.08, brightness: 0.97)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Preview Area
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(internalColorValue.gradient)
                            .frame(height: 180)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: internalColorValue.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        TextField("Color Name", text: $internalName)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Color Picker (Real-time wheel representation using standard component for robust hue selection)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Color Wheel")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ColorPicker("Select Color", selection: Binding(
                            get: { internalColorValue },
                            set: { newValue in
                                internalColorValue = newValue
                                syncTextToColor()
                            }
                        ), supportsOpacity: false)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaleEffect(CGSize(width: 1.5, height: 1.5))
                            .padding(.vertical, 16)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Sliders
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Adjustments")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            AdjustmentSlider(
                                title: "Temperature",
                                valueLabel: ColorAdjustment.offsetLabel(temperatureValue, positive: "warm", negative: "cool"),
                                leftLabel: "Cool",
                                rightLabel: "Warm",
                                value: Binding(
                                    get: { temperatureValue },
                                    set: { v in temperatureValue = v; applySliderAdjustments() }
                                )
                            )
                            AdjustmentSlider(
                                title: "Saturation",
                                valueLabel: ColorAdjustment.offsetLabel(saturationValue),
                                leftLabel: "Muted",
                                rightLabel: "Vivid",
                                value: Binding(
                                    get: { saturationValue },
                                    set: { v in saturationValue = v; applySliderAdjustments() }
                                )
                            )
                            AdjustmentSlider(
                                title: "Brightness",
                                valueLabel: ColorAdjustment.offsetLabel(brightnessValue),
                                leftLabel: "Dark",
                                rightLabel: "Light",
                                value: Binding(
                                    get: { brightnessValue },
                                    set: { v in brightnessValue = v; applySliderAdjustments() }
                                )
                            )
                        }
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Values Editor
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Values")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            // HEX Field
                            HStack {
                                Text("HEX")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 50, alignment: .leading)
                                
                                Text("#")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                
                                TextField("FF0000", text: Binding(
                                    get: { internalHex },
                                    set: { newValue in
                                        internalHex = newValue
                                        hexError = false
                                        updateColorFromHex(newValue)
                                    }
                                ))
                                    .font(.system(size: 16, design: .monospaced))
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                            }
                            .padding(12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(hexError ? Color.red : Color.clear, lineWidth: 1.5)
                            )
                            
                            // RGB Fields
                            HStack(spacing: 12) {
                                rgbField(label: "R", text: $rString)
                                rgbField(label: "G", text: $gString)
                                rgbField(label: "B", text: $bString)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    colors: [internalColorValue.opacity(0.8), gradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Edit Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        handleSaveTapped()
                    }
                    .buttonStyle(.glassProminent)
                    .fontWeight(.semibold)
                }
            }
            .alert("Overwrite or Create New?", isPresented: $showOverwriteAlert) {
                Button("Overwrite Existing") {
                    saveChanges(isOverwrite: true)
                    dismiss()
                }
                Button("Create New Color") {
                    saveChanges(isOverwrite: false)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You changed this color without changing its name. Would you like to overwrite it globally or create a new global color?")
            }
            .onAppear {
                internalName = colorName
                originalName = colorName
                
                let hc = hexCode.hasPrefix("#") ? String(hexCode.dropFirst()) : hexCode
                internalHex = hc
                originalHex = hc
                
                internalColorValue = colorValue
                syncTextToColor()
                resetSlidersAndSetBase()
            }
        }
    }
    
    // MARK: - Subcomponents
    
    @ViewBuilder
    private func rgbField(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextField("0", text: Binding(
                get: { text.wrappedValue },
                set: { newValue in
                    let filtered = newValue.filter { "0123456789".contains($0) }
                    if filtered != text.wrappedValue {
                        text.wrappedValue = filtered
                    }
                    updateColorFromRGB()
                }
            ))
                .font(.system(size: 16, design: .monospaced))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }
    
    // MARK: - Logic
    
    private func syncTextToColor() {
        // Convert Color to RGB and Hex
        let comps = internalColorValue.rgbComponents
        let rInt = Int(round(comps.r))
        let gInt = Int(round(comps.g))
        let bInt = Int(round(comps.b))
        
        rString = "\(rInt)"
        gString = "\(gInt)"
        bString = "\(bInt)"
        
        internalHex = String(format: "%02X%02X%02X", rInt, gInt, bInt)
        
        resetSlidersAndSetBase()
    }
    
    private func updateColorFromHex(_ hex: String) {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanHex.count == 6 else { return }
        if let newColor = Color(hex: cleanHex) {
            internalColorValue = newColor

            // Sync RGB text to match new hex
            let c = newColor.rgbComponents
            rString = "\(Int(round(c.r)))"
            gString = "\(Int(round(c.g)))"
            bString = "\(Int(round(c.b)))"

            resetSlidersAndSetBase()
        } else {
            hexError = true
        }
    }
    
    private func updateColorFromRGB() {
        guard let rVal = Int(rString), rVal <= 255,
              let gVal = Int(gString), gVal <= 255,
              let bVal = Int(bString), bVal <= 255 else { return }
        
        let newColor = Color(red: Double(rVal) / 255, green: Double(gVal) / 255, blue: Double(bVal) / 255)
        internalColorValue = newColor
        
        // Sync hex text
        internalHex = String(format: "%02X%02X%02X", rVal, gVal, bVal)
        resetSlidersAndSetBase()
    }
    
    // MARK: - Slider Logic

    private var adjustedRGB: (r: Double, g: Double, b: Double) {
        ColorAdjustment.apply(
            baseR: baseR, baseG: baseG, baseB: baseB,
            temperature: temperatureValue,
            saturation: saturationValue,
            brightness: brightnessValue
        )
    }

    private func applySliderAdjustments() {
        let c = adjustedRGB
        let newColor = Color(red: c.r / 255.0, green: c.g / 255.0, blue: c.b / 255.0)
        
        internalColorValue = newColor
        
        rString = "\(Int(round(c.r)))"
        gString = "\(Int(round(c.g)))"
        bString = "\(Int(round(c.b)))"
        internalHex = String(format: "%02X%02X%02X", Int(round(c.r)), Int(round(c.g)), Int(round(c.b)))
    }

    private func resetSlidersAndSetBase() {
        let c = internalColorValue.rgbComponents
        baseR = Double(Int(round(c.r)))
        baseG = Double(Int(round(c.g)))
        baseB = Double(Int(round(c.b)))
        
        temperatureValue = 0.5
        saturationValue = 0.5
        brightnessValue = 0.5
    }
    
    private func handleSaveTapped() {
        let hasHexChanged = internalHex.caseInsensitiveCompare(originalHex) != .orderedSame
        let hasNameChanged = internalName != originalName
        
        if promptOnNameMatch && !hasNameChanged && hasHexChanged {
            showOverwriteAlert = true
        } else {
            saveChanges(isOverwrite: false) // default behavior
            dismiss()
        }
    }
    
    private func saveChanges(isOverwrite: Bool) {
        colorName = internalName.isEmpty ? "Untitled" : internalName
        hexCode = "#\(internalHex)"
        colorValue = internalColorValue
        
        if let action = onSaveWithAction {
            action(isOverwrite)
        } else {
            onSave()
        }
    }
}

#Preview {
    ColorEditView(
        colorName: .constant("Crimson"),
        hexCode: .constant("#DC143C"),
        colorValue: .constant(Color(red: 220/255, green: 20/255, blue: 60/255))
    )
    .environmentObject(AppData())
}
