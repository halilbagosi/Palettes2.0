import SwiftUI

/// Full-screen photo color sampler. Presented modally (never inside a
/// ScrollView), so the drag-to-sample gesture is reliable across the whole
/// image. A crosshair is drawn at the *exact* sampled point and the touch is
/// clamped to the on-screen image rect, so "where the finger is" always matches
/// the sampled color — including at the edges. A liquid-glass panel floats over
/// the photo showing the live color.
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
    @State private var marker: CGPoint?   // finger position, clamped to the image rect
    @State private var sampler: ImageColorExtractor.PixelSampler?

    private var currentColor: Color {
        Color(red: currentRGB.r / 255, green: currentRGB.g / 255, blue: currentRGB.b / 255)
    }

    private var currentHex: String {
        String(format: "#%02X%02X%02X",
               Int(round(currentRGB.r)), Int(round(currentRGB.g)), Int(round(currentRGB.b)))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let rect = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: geo.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)

                    if let m = marker {
                        markerView.position(m)
                    }

                    VStack {
                        Spacer()
                        previewPanel
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in sample(at: value.location, in: rect) }
                        .onEnded { _ in
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                        }
                )
            }
            .navigationTitle("Pick Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(currentRGB)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasSample)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                sampler = ImageColorExtractor.PixelSampler(image: image)
                if let seed = initialRGB {
                    currentRGB = seed
                    hasSample = true
                    currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sampling

    private func sample(at location: CGPoint, in rect: CGRect) {
        let clamped = CGPoint(
            x: min(max(location.x, rect.minX), rect.maxX),
            y: min(max(location.y, rect.minY), rect.maxY)
        )
        marker = clamped
        let normalized = PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
        let rgb = sampler?.color(at: normalized, radius: 2)
            ?? ImageColorExtractor.sampleColor(from: image, at: normalized, radius: 2)
        currentRGB = rgb
        hasSample = true
    }

    // MARK: - Marker

    /// A crosshair ring at the exact sample point, with a color bubble floating
    /// above the fingertip so the finger doesn't cover the picked color.
    private var markerView: some View {
        ZStack {
            Circle().stroke(.white, lineWidth: 2).frame(width: 20, height: 20)
            Circle().stroke(.black.opacity(0.4), lineWidth: 1).frame(width: 22, height: 22)
            Rectangle().fill(.white).frame(width: 1, height: 8).blendMode(.difference)
            Rectangle().fill(.white).frame(width: 8, height: 1).blendMode(.difference)
        }
        .overlay(alignment: .center) {
            Circle()
                .fill(currentColor)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 4)
                .offset(y: -52)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Preview

    private var previewPanel: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(currentColor.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
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
