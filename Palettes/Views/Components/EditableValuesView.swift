import SwiftUI

struct EditableValuesView: View {
    let color: Color
    var onColorChanged: (Color) -> Void
    
    @State private var currentHex: String = ""
    @State private var rString: String = "255"
    @State private var gString: String = "255"
    @State private var bString: String = "255"
    
    @State private var isSyncing = false
    @State private var hexError = false
    
    var body: some View {
        VStack(spacing: 12) {
            // HEX Field
            HStack {
                Text("HEX")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, alignment: .leading)
                    .foregroundColor(.secondary)
                
                Text("#")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                TextField("000000", text: $currentHex)
                    .font(.system(size: 16, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: currentHex) { newValue in
                        guard !isSyncing else { return }
                        hexError = false
                        let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        if clean.count == 6, let newColor = Color(hex: clean) {
                            isSyncing = true
                            // Sync RGB fields to match
                            let uiC = UIColor(newColor)
                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                            uiC.getRed(&r, green: &g, blue: &b, alpha: &a)
                            rString = "\(Int(round(r * 255)))"
                            gString = "\(Int(round(g * 255)))"
                            bString = "\(Int(round(b * 255)))"
                            isSyncing = false
                            onColorChanged(newColor)
                        } else if clean.count > 6 {
                           hexError = true
                        }
                    }
                
                Spacer()
                
                Button {
                    copyToClipboard(currentHex, label: "Copied HEX")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(hexError ? Color.red : Color.primary.opacity(0.1), lineWidth: hexError ? 1.5 : 1)
            )
            
            // RGB Fields
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
        }
        .onChange(of: color) { newColor in
            syncText(from: newColor)
        }
        .onAppear {
            syncText(from: color)
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
                .onChange(of: text.wrappedValue) { newValue in
                    let filtered = newValue.filter { "0123456789".contains($0) }
                    if filtered != newValue {
                        text.wrappedValue = filtered
                    }
                    guard !isSyncing else { return }
                    if let r = Int(rString), r <= 255,
                       let g = Int(gString), g <= 255,
                       let b = Int(bString), b <= 255 {
                        isSyncing = true
                        let newColor = Color(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
                        // Sync HEX field to match
                        currentHex = String(format: "%02X%02X%02X", r, g, b)
                        isSyncing = false
                        onColorChanged(newColor)
                    }
                }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
    
    private func syncText(from c: Color) {
        isSyncing = true
        let uiColor = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rInt = Int(round(r * 255))
        let gInt = Int(round(g * 255))
        let bInt = Int(round(b * 255))
        
        currentHex = String(format: "%02X%02X%02X", rInt, gInt, bInt)
        rString = "\(rInt)"
        gString = "\(gInt)"
        bString = "\(bInt)"
        
        DispatchQueue.main.async {
            isSyncing = false
        }
    }
}
