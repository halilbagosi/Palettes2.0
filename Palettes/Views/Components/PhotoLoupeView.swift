import SwiftUI

/// Interactive photo eyedropper. Displays an image and lets the user press
/// and drag a magnifier loupe to sample any point's color. Reports sampled
/// colors out via callbacks and owns none of the host's scan state.
///
/// At rest the image is aspect-fill (matching the surrounding preview look).
/// While dragging it animates to aspect-fit so every region is reachable, and
/// `PhotoLoupeGeometry` maps the touch to a normalized image point.
struct PhotoLoupeView: View {
    let image: UIImage
    var cornerRadius: CGFloat = 20
    let onSample: (_ rgb: (r: Double, g: Double, b: Double)) -> Void
    let onSampleEnd: () -> Void
    /// Reports when a drag-to-sample begins (`true`) and ends (`false`) so a
    /// host can suppress an enclosing ScrollView from stealing the gesture.
    var onSamplingChanged: (Bool) -> Void = { _ in }

    @State private var touchPoint: CGPoint?
    @State private var isDragging = false
    @State private var loupeColor: Color = .gray

    // Rasterized once per image so drag sampling doesn't re-render the photo
    // on every touch-move frame.
    @State private var sampler: ImageColorExtractor.PixelSampler?

    private let loupeDiameter: CGFloat = 110
    private let loupeZoom: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: isDragging ? .fit : .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.2), value: isDragging)

                if isDragging, let pt = touchPoint {
                    loupe(at: pt, in: geo.size)
                }

                if !isDragging {
                    hint
                }
            }
            .contentShape(Rectangle())
            // High priority so the loupe wins gesture arbitration against an
            // enclosing ScrollView's pan (the host also disables scrolling
            // while sampling via onSamplingChanged).
            .highPriorityGesture(dragGesture(in: geo.size))
            .onAppear {
                if sampler == nil {
                    sampler = ImageColorExtractor.PixelSampler(image: image)
                }
            }
            .onChange(of: ObjectIdentifier(image)) { _, _ in
                sampler = ImageColorExtractor.PixelSampler(image: image)
            }
        }
    }

    // MARK: - Hint

    private var hint: some View {
        VStack {
            Spacer()
            Label("Drag to pick a color", systemImage: "eyedropper")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 10)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Loupe

    private func loupe(at point: CGPoint, in size: CGSize) -> some View {
        // Position the loupe above the finger; flip below when near the top.
        let gap: CGFloat = loupeDiameter / 2 + 28
        let above = point.y > loupeDiameter + 24
        let centerY = above ? point.y - gap : point.y + gap

        return ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .scaleEffect(loupeZoom)
                .offset(
                    x: (size.width / 2 - point.x) * loupeZoom,
                    y: (size.height / 2 - point.y) * loupeZoom
                )
                .frame(width: loupeDiameter, height: loupeDiameter)
                .clipShape(Circle())

            // Crosshair
            Rectangle().fill(.white).frame(width: 1, height: 14).blendMode(.difference)
            Rectangle().fill(.white).frame(width: 14, height: 1).blendMode(.difference)

            Circle()
                .stroke(Color.white, lineWidth: 3)
            Circle()
                .stroke(Color.black.opacity(0.25), lineWidth: 1)
        }
        .frame(width: loupeDiameter, height: loupeDiameter)
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(loupeColor)
                .frame(width: 44, height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.white, lineWidth: 1.5)
                )
                .offset(y: 18)
        }
        .shadow(radius: 6)
        .position(x: point.x, y: centerY)
        .allowsHitTesting(false)
    }

    // MARK: - Gesture

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    onSamplingChanged(true)
                }
                touchPoint = value.location
                let normalized = PhotoLoupeGeometry.normalizedPoint(
                    forViewPoint: value.location,
                    viewSize: size,
                    imageSize: image.size
                )
                let rgb = sampler?.color(at: normalized, radius: 2)
                    ?? ImageColorExtractor.sampleColor(from: image, at: normalized, radius: 2)
                loupeColor = Color(
                    red: rgb.r / 255, green: rgb.g / 255, blue: rgb.b / 255
                )
                onSample(rgb)
            }
            .onEnded { _ in
                isDragging = false
                touchPoint = nil
                onSamplingChanged(false)
                onSampleEnd()
            }
    }
}

#Preview {
    let img = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 200)).image { ctx in
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow]
        for (i, c) in colors.enumerated() {
            c.setFill()
            ctx.fill(CGRect(x: CGFloat(i) * 75, y: 0, width: 75, height: 200))
        }
    }
    return PhotoLoupeView(image: img, onSample: { _ in }, onSampleEnd: {})
        .frame(height: 200)
        .padding()
}
