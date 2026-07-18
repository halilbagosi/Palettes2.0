import SwiftUI

/// Full-screen photo color sampler. Because it is presented modally (not inside
/// a ScrollView), the drag-to-sample gesture has no scroll to fight, so the
/// user can pick a color from *any* part of the image reliably.
///
/// Reuses `PhotoLoupeView` for the image + magnifier loupe, adds a
/// liquid-glass preview panel for the live color, and commits the chosen color
/// via `onUse`.
struct PhotoColorPickerView: View {
    let image: UIImage
    /// Seeds the preview before the user drags (e.g. the auto-extracted
    /// dominant color), so there is always a valid initial selection.
    var initialRGB: (r: Double, g: Double, b: Double)? = nil
    let onUse: (_ rgb: (r: Double, g: Double, b: Double)) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentRGB: (r: Double, g: Double, b: Double) = (128, 128, 128)
    @State private var currentName = ""
    @State private var hasSample = false

    private var currentColor: Color {
        Color(red: currentRGB.r / 255, green: currentRGB.g / 255, blue: currentRGB.b / 255)
    }

    private var currentHex: String {
        String(format: "#%02X%02X%02X",
               Int(round(currentRGB.r)), Int(round(currentRGB.g)), Int(round(currentRGB.b)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                PhotoLoupeView(
                    image: image,
                    alwaysFit: true,
                    // Live during drag: update the color only. Naming is
                    // deferred to release to keep dragging smooth.
                    onSample: { rgb in
                        currentRGB = rgb
                        hasSample = true
                    },
                    onSampleEnd: {
                        currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                previewPanel
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .background(Color(.systemBackground))
            .navigationTitle("Pick Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(currentRGB)
                        dismiss()
                    }
                    .glassButton(prominent: true)
                    .fontWeight(.semibold)
                    .disabled(!hasSample)
                }
            }
            .onAppear {
                if let seed = initialRGB {
                    currentRGB = seed
                    hasSample = true
                    currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                }
            }
        }
    }

    // MARK: - Preview

    private var previewPanel: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(currentColor.gradient)
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(currentName.isEmpty ? "Drag on the photo" : currentName)
                    .font(.headline)
                    .foregroundStyle(currentName.isEmpty ? .secondary : .primary)
                Text(currentHex)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .liquidGlass(.regular, in: .rect(cornerRadius: 24))
    }
}

#Preview {
    let img = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500)).image { ctx in
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemOrange, .systemPurple]
        for (i, c) in colors.enumerated() {
            c.setFill()
            ctx.fill(CGRect(x: 0, y: CGFloat(i) * 100, width: 400, height: 100))
        }
    }
    return PhotoColorPickerView(image: img, onUse: { _ in })
}
