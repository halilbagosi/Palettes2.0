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
    /// Onboarding: a plain black (dark) or white (light) stage instead of the
    /// always-dark viewer, with the photo centred in the space above the panel.
    var adaptiveStage = false
    /// Replaces `dismiss()` when the picker is shown as an overlay, not a cover.
    var onClose: (() -> Void)? = nil
    let onUse: (_ rgb: (r: Double, g: Double, b: Double)) -> Void
    /// Also called on Use, with where the color was sampled (normalized image
    /// coordinates), or nil when the seed color was used untouched.
    var onUseSample: ((_ rgb: (r: Double, g: Double, b: Double), _ point: CGPoint?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var sampledPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentRGB: (r: Double, g: Double, b: Double) = (128, 128, 128)
    @State private var currentName = ""
    @State private var hasSample = false
    @State private var marker: CGPoint?   // finger position, clamped to the image rect
    @State private var sampler: ImageColorExtractor.PixelSampler?
    @State private var dragVelocity: CGSize = .zero   // finger speed → bubble squish physics

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
                // The adaptive stage keeps the photo clear of the bottom panel.
                let rect = PhotoLoupeGeometry.imageRect(
                    imageSize: image.size,
                    in: adaptiveStage ? CGSize(width: geo.size.width, height: max(0, geo.size.height - 130)) : geo.size)

                ZStack {
                    (adaptiveStage && colorScheme == .light ? Color.white : Color.black).ignoresSafeArea()

                    photo(in: rect, container: geo.size)
                        .accessibilityLabel("Photo")
                        .accessibilityHint("Use the actions to pick the center or the suggested color, or double-tap and hold, then drag.")
                        .accessibilityAction(named: "Pick Color at Center") {
                            sample(at: CGPoint(x: rect.midX, y: rect.midY), in: rect)
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                            UIAccessibility.post(notification: .announcement, argument: "Selected \(currentName.isEmpty ? currentHex : currentName), \(currentHex)")
                        }
                        .accessibilityActions {
                            if let seed = initialRGB {
                                Button("Use Suggested Color") {
                                    currentRGB = seed
                                    hasSample = true
                                    marker = nil
                                    sampledPoint = nil
                                    currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                                    UIAccessibility.post(notification: .announcement, argument: "Selected \(currentName.isEmpty ? currentHex : currentName), \(currentHex)")
                                }
                            }
                        }

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
                        .onChanged { value in
                            dragVelocity = value.velocity
                            sample(at: value.location, in: rect)
                        }
                        .onEnded { _ in
                            dragVelocity = .zero   // let the bubble spring back / bounce
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                        }
                )
            }
            .navigationTitle("Pick Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { close() } label: {
                        Label("Cancel", systemImage: "xmark").foregroundStyle(adaptiveStage ? Color.primary : .white)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        onUse(currentRGB)
                        onUseSample?(currentRGB, sampledPoint)
                        close()
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
        .preferredColorScheme(adaptiveStage ? nil : .dark)
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// The photo, aspect-fit. On the adaptive stage it is drawn in its own rect.
    @ViewBuilder
    private func photo(in rect: CGRect, container: CGSize) -> some View {
        if adaptiveStage {
            Image(uiImage: image)
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        } else {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: container.width, height: container.height)
        }
    }

    // MARK: - Sampling

    private func sample(at location: CGPoint, in rect: CGRect) {
        let clamped = CGPoint(
            x: min(max(location.x, rect.minX), rect.maxX),
            y: min(max(location.y, rect.minY), rect.maxY)
        )
        marker = clamped
        let normalized = PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
        sampledPoint = normalized
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
            colorBubble.offset(y: -84)
        }
        .allowsHitTesting(false)
    }

    /// The bubble that floats above the fingertip: an opaque disc of the sampled
    /// color sealed inside a clear liquid-glass shell. It squishes along the
    /// drag axis in proportion to finger speed — the same stretch language the
    /// generate orb uses — and springs back with a little bounce on release.
    private var colorBubble: some View {
        let vx = max(-1, min(1, dragVelocity.width / 2500))
        let vy = max(-1, min(1, dragVelocity.height / 2500))

        return ZStack {
            // Clear liquid-glass circle — refracts the photo behind it.
            Circle()
                .fill(.clear)
                .liquidGlass(.clear, in: .circle)
                .frame(width: 112, height: 112)

            // A plain (non-glass) disc of the color currently being picked,
            // sitting inside the glass so the exact color reads at a glance.
            Circle()
                .fill(currentColor)
                .frame(width: 86, height: 86)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
        }
        // Stretch toward the direction of travel, thinning on the cross axis.
        .scaleEffect(
            x: reduceMotion ? 1 : 1 + abs(vx) * 0.45 - abs(vy) * 0.12,
            y: reduceMotion ? 1 : 1 + abs(vy) * 0.45 - abs(vx) * 0.12
        )
        .shadow(radius: 4)
        // Under-damped spring → the squish overshoots and bounces as speed
        // changes and when the finger lifts.
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.5), value: dragVelocity)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasSample ? "Selected color \(currentName.isEmpty ? currentHex : currentName), \(currentHex)" : "No color selected")
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
