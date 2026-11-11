import SwiftUI

/// Full-screen photo color sampler. Presented modally (never inside a
/// ScrollView), so the drag-to-sample gesture is reliable across the whole
/// image. A crosshair is drawn at the *exact* sampled point and the touch is
/// clamped to the on-screen image rect, so "where the finger is" always matches
/// the sampled color — including at the edges. Pinching zooms and pans the
/// photo for finer picking. A liquid-glass panel floats over the photo showing
/// the live color.
struct PhotoColorPickerView: View {
    let image: UIImage
    /// Seeds the preview before the user drags (e.g. the auto-extracted
    /// dominant color), so there is always a valid initial selection.
    var initialRGB: (r: Double, g: Double, b: Double)? = nil
    /// Where the marker starts (normalized image coordinates), sampling the
    /// color under it, ready to be dragged.
    var initialPoint: CGPoint? = nil
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

    @State private var currentRGB: (r: Double, g: Double, b: Double) = (128, 128, 128)
    @State private var currentName = ""
    @State private var hasSample = false
    @State private var zoom = PhotoZoom()
    /// The selection before the touch in progress, restored if that touch
    /// turns out to be the first finger of a pinch.
    @State private var beforeTouch: Selection?
    @State private var isTouching = false
    @State private var sampler: ImageColorExtractor.PixelSampler?
    @State private var dragVelocity: CGSize = .zero   // finger speed → bubble squish physics

    private struct Selection {
        var rgb: (r: Double, g: Double, b: Double)
        var name: String
        var hasSample: Bool
        var point: CGPoint?
    }

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
                let stage = adaptiveStage ? CGSize(width: geo.size.width, height: max(0, geo.size.height - 130)) : geo.size
                // Where the photo rests, and where it is drawn once zoomed.
                let base = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: stage)
                let rect = zoom.rect(for: base)
                let window = CGRect(origin: .zero, size: stage)
                let bounds = CGRect(origin: .zero, size: geo.size)

                ZStack {
                    (adaptiveStage && colorScheme == .light ? Color.white : Color.black).ignoresSafeArea()

                    photo(in: base, container: geo.size)
                        .accessibilityLabel("Photo")
                        .accessibilityHint("Use the actions to pick the center or the suggested color, or double-tap and hold, then drag. Pinch to zoom.")
                        .accessibilityZoomAction { action in
                            let center = CGPoint(x: window.midX, y: window.midY)
                            zoom.pinch(by: action.direction == .zoomIn ? 2 : 0.5, from: center, to: center,
                                       base: base, window: window)
                        }
                        .accessibilityAction(named: "Pick Color at Center") {
                            sample(at: CGPoint(x: window.midX, y: window.midY), in: rect, visible: bounds)
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                            UIAccessibility.post(notification: .announcement, argument: "Selected \(currentName.isEmpty ? currentHex : currentName), \(currentHex)")
                        }
                        .accessibilityActions {
                            if let seed = initialRGB, !hasSample {
                                Button("Use Suggested Color") {
                                    currentRGB = seed
                                    hasSample = true
                                    sampledPoint = nil
                                    currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                                    UIAccessibility.post(notification: .announcement, argument: "Selected \(currentName.isEmpty ? currentHex : currentName), \(currentHex)")
                                }
                            }
                        }

                    // The drag layer sits under the panel, so the panel's own
                    // controls (the system color picker) still get their taps.
                    PhotoTouchLayer(
                        onSample: { location, velocity in
                            if !isTouching {
                                isTouching = true
                                beforeTouch = Selection(rgb: currentRGB, name: currentName,
                                                        hasSample: hasSample, point: sampledPoint)
                            }
                            dragVelocity = velocity
                            sample(at: location, in: rect, visible: bounds)
                        },
                        onSampleEnded: {
                            isTouching = false
                            dragVelocity = .zero   // let the bubble spring back / bounce
                            currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
                        },
                        onPinchBegan: { wasTap in
                            // The first finger of a pinch isn't a pick: put the selection back.
                            if wasTap, let before = beforeTouch {
                                currentRGB = before.rgb
                                currentName = before.name
                                hasSample = before.hasSample
                                sampledPoint = before.point
                            }
                        },
                        onPinch: { factor, previous, current in
                            zoom.pinch(by: factor, from: previous, to: current, base: base, window: window)
                        }
                    )
                    .accessibilityHidden(true)

                    // The marker rides the photo, so it stays on the sampled spot while zooming.
                    if let point = sampledPoint {
                        PhotoSampleMarker(color: currentColor, dragVelocity: dragVelocity)
                            .position(PhotoPinGeometry.position(of: point, in: rect))
                    }

                    VStack {
                        Spacer()
                        previewPanel
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                    }
                }
                // The first layout can be empty; place the marker once the photo has a size.
                .onAppear { placeInitialMarker(in: base) }
                .onChange(of: base.size) { _, _ in placeInitialMarker(in: base) }
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
                    // Choosing a color, not adding one to a palette: a checkmark.
                    SheetConfirmButton(kind: .save) {
                        onUse(currentRGB)
                        onUseSample?(currentRGB, sampledPoint)
                        close()
                    }
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

    /// The photo, aspect-fit and zoomed about its own center. On the adaptive
    /// stage it is drawn in its own (unzoomed) rect.
    @ViewBuilder
    private func photo(in rect: CGRect, container: CGSize) -> some View {
        if adaptiveStage {
            Image(uiImage: image)
                .resizable()
                .frame(width: rect.width, height: rect.height)
                .scaleEffect(zoom.scale)
                .position(x: rect.midX, y: rect.midY)
                .offset(zoom.offset)
        } else {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: container.width, height: container.height)
                .scaleEffect(zoom.scale)
                .offset(zoom.offset)
        }
    }

    // MARK: - Sampling

    private func placeInitialMarker(in rect: CGRect) {
        guard let initialPoint, sampledPoint == nil, rect.width > 0, rect.height > 0 else { return }
        sample(at: PhotoPinGeometry.position(of: initialPoint, in: rect), in: rect, visible: rect)
        currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
    }

    /// Samples under `location`, clamped to the part of the photo (drawn in
    /// `rect`) that is on screen.
    private func sample(at location: CGPoint, in rect: CGRect, visible: CGRect) {
        let shown = rect.intersection(visible)
        guard !shown.isNull else { return }
        let clamped = CGPoint(
            x: min(max(location.x, shown.minX), shown.maxX),
            y: min(max(location.y, shown.minY), shown.maxY)
        )
        let normalized = PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
        sampledPoint = normalized
        let rgb = sampler?.color(at: normalized, radius: 2)
            ?? ImageColorExtractor.sampleColor(from: image, at: normalized, radius: 2)
        currentRGB = rgb
        hasSample = true
    }

    // MARK: - Preview

    /// Bridges the system `ColorPicker` to the sampled RGB (0–255 channels).
    private var adjustedColor: Binding<Color> {
        Binding(
            get: { currentColor },
            set: { new in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard UIColor(new).getRed(&r, green: &g, blue: &b, alpha: &a) else { return }
                currentRGB = (Double(r) * 255, Double(g) * 255, Double(b) * 255)
                hasSample = true
                currentName = ColorNamer.name(forHex: String(currentHex.dropFirst()))
            }
        )
    }

    private var previewPanel: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(currentColor)
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

            // Before iOS 26: the system color picker (spectrum, sliders, and its
            // own eyedropper) to fine-tune the sampled color.
            if #unavailable(iOS 26.0) {
                ColorPicker("Adjust Color", selection: adjustedColor, supportsOpacity: false)
                    .labelsHidden()
                    .scaleEffect(1.25)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(18)
        .liquidGlass(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasSample ? "Selected color \(currentName.isEmpty ? currentHex : currentName), \(currentHex)" : "No color selected")
    }
}

// MARK: - Marker

/// A crosshair ring at the exact sample point, with a color bubble floating
/// above the fingertip so the finger doesn't cover the picked color.
struct PhotoSampleMarker: View {
    let color: Color
    /// Finger speed; the bubble squishes along the drag.
    var dragVelocity: CGSize = .zero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
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

    /// iOS 26: the disc sealed inside a clear liquid-glass shell. Earlier: the
    /// system eyedropper's look, a disc of the color in an ultra-thin material ring.
    @ViewBuilder
    private var bubble: some View {
        if #available(iOS 26.0, *) {
            ZStack {
                Circle()
                    .fill(.clear)
                    .liquidGlass(.clear, in: .circle)
                    .frame(width: 112, height: 112)
                Circle()
                    .fill(color)
                    .frame(width: 86, height: 86)
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            }
        } else {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 108, height: 108)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.5))
                Circle()
                    .fill(color)
                    .frame(width: 88, height: 88)
                    .overlay(Circle().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
            }
        }
    }

    /// The bubble that floats above the fingertip: an opaque disc of the sampled
    /// color sealed inside a clear liquid-glass shell. It squishes along the
    /// drag axis in proportion to finger speed — the same stretch language the
    /// generate orb uses — and springs back with a little bounce on release.
    private var colorBubble: some View {
        let vx = max(-1, min(1, dragVelocity.width / 2500))
        let vy = max(-1, min(1, dragVelocity.height / 2500))

        return bubble
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
