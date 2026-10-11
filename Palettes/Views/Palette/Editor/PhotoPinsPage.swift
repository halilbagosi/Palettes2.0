//
//  PhotoPinsPage.swift
//  Palettes
//
//  "From a Photo". Colors are pulled from the photo automatically, then the
//  photo is shown with a pin where each one was found. Dragging a pin picks a
//  different color; the strip under the photo follows live. "+ Add N" hands
//  the colors to the editor.
//

import SwiftUI

/// Pure geometry for the pins, kept apart from SwiftUI so it can be tested.
/// Points are normalized image coordinates (0…1, top-left origin).
enum PhotoPinGeometry {
    /// Where a pin that started at `origin` ends up after the finger moved by
    /// `translation` (view points), clamped to the image rect.
    static func moved(from origin: CGPoint, by translation: CGSize, in rect: CGRect) -> CGPoint {
        let start = position(of: origin, in: rect)
        let target = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        let clamped = CGPoint(
            x: min(max(target.x, rect.minX), rect.maxX),
            y: min(max(target.y, rect.minY), rect.maxY)
        )
        return PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
    }

    /// 5% of the image width per VoiceOver step, left (-1) or right (+1).
    static func nudged(_ point: CGPoint, by direction: Int) -> CGPoint {
        CGPoint(x: min(max(point.x + 0.05 * Double(direction), 0), 1), y: point.y)
    }

    /// The view position of a normalized point.
    static func position(of point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
    }
}

struct PhotoPinsPage: View {
    let image: UIImage
    let onAdd: ([PaletteColor]) -> Void

    struct Pin: Identifiable, Equatable {
        let id: Int
        var point: CGPoint
        var hex: String
        /// The name belongs to `nameHex`; it is refreshed when a drag ends.
        var name: String
        var nameHex: String
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pins: [Pin] = []
    @State private var sampler: ImageColorExtractor.PixelSampler?
    @State private var isLoading = true
    @State private var draggingID: Int?
    /// Where the dragged pin was when the finger went down.
    @State private var dragOrigin: CGPoint?

    private static let pinSize: CGFloat = 30
    private static let space = "photoPins"

    private var colors: [PaletteColor] {
        var seen = Set<String>()
        return pins.compactMap { pin in
            guard seen.insert(pin.hex.uppercased()).inserted, let color = Color(hex: pin.hex) else { return nil }
            let name = pin.nameHex == pin.hex ? pin.name : ColorNamer.name(forHex: pin.hex)
            return PaletteColor(color: color, hex: pin.hex, name: name)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let rect = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel("Photo")

                    ForEach(Array(pins.enumerated()), id: \.element.id) { offset, pin in
                        pinView(pin, number: offset + 1, rect: rect)
                    }

                    if isLoading {
                        ProgressView()
                    }
                }
                .coordinateSpace(name: Self.space)
            }
            // Room for a pin to hang over the photo's edge.
            .padding(.horizontal, Self.pinSize / 2 + 4)
            .padding(.vertical, Self.pinSize / 2)

            PaletteStrip(colors: pins.compactMap { Color(hex: $0.hex) }, height: 56)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .accessibilityHidden(true)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("From a Photo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                SheetConfirmButton(kind: .add(count: colors.count)) { onAdd(colors) }
                    .disabled(colors.isEmpty)
            }
        }
        .task { await load() }
    }

    // MARK: - Pin

    private func pinView(_ pin: Pin, number: Int, rect: CGRect) -> some View {
        let lifted = draggingID == pin.id
        let color = Color(hex: pin.hex) ?? .gray
        return Circle()
            .fill(color)
            .frame(width: Self.pinSize, height: Self.pinSize)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .overlay(alignment: .topTrailing) {
                Text("\(number)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(.black.opacity(0.7)))
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
            .scaleEffect(lifted && !reduceMotion ? 1.15 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.2), value: lifted)
            // A comfortable touch target around the 30 pt pin.
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(PhotoPinGeometry.position(of: pin.point, in: rect))
            .zIndex(lifted ? 1 : 0)
            .gesture(drag(pin.id, in: rect))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Color \(number), \(pin.name)")
            .accessibilityValue(pin.hex)
            .accessibilityHint("Swipe up or down to move it right or left across the photo.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: nudge(pin.id, by: 1)
                case .decrement: nudge(pin.id, by: -1)
                @unknown default: break
                }
            }
    }

    private func drag(_ id: Int, in rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if draggingID != id {
                    draggingID = id
                    dragOrigin = pins.first { $0.id == id }?.point
                }
                guard let origin = dragOrigin else { return }
                // The pin tracks the finger 1:1, so nothing here animates.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    place(id, at: PhotoPinGeometry.moved(from: origin, by: value.translation, in: rect))
                }
            }
            .onEnded { _ in
                draggingID = nil
                dragOrigin = nil
                refreshName(of: id)
            }
    }

    // MARK: - Pins

    /// Moves a pin and re-reads the color under it.
    private func place(_ id: Int, at point: CGPoint) {
        guard let i = pins.firstIndex(where: { $0.id == id }) else { return }
        pins[i].point = point
        if let sampler {
            let rgb = sampler.color(at: point, radius: 2)
            pins[i].hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: rgb.b)
        }
    }

    private func refreshName(of id: Int) {
        guard let i = pins.firstIndex(where: { $0.id == id }), pins[i].nameHex != pins[i].hex else { return }
        pins[i].name = ColorNamer.name(forHex: pins[i].hex)
        pins[i].nameHex = pins[i].hex
    }

    private func nudge(_ id: Int, by direction: Int) {
        guard let pin = pins.first(where: { $0.id == id }) else { return }
        place(id, at: PhotoPinGeometry.nudged(pin.point, by: direction))
        refreshName(of: id)
        if let moved = pins.first(where: { $0.id == id }) {
            UIAccessibility.post(notification: .announcement, argument: moved.name)
        }
    }

    // MARK: - Loading

    /// Pulls the colors, then finds where each sits in the photo. Waits out the
    /// push first so the transition isn't stalled by the work.
    private func load() async {
        try? await Task.sleep(for: .milliseconds(300))
        guard let sampler = ImageColorExtractor.PixelSampler(image: image) else {
            fail(AppError.imageProcessingFailed.localizedDescription)
            return
        }
        do {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 6)
            guard !extracted.isEmpty else {
                fail("Couldn't find any colors in that photo")
                return
            }
            let points = PhotoPinLocator.locate(hexes: extracted.map(\.hex), in: sampler)
            self.sampler = sampler
            pins = zip(extracted.indices, zip(extracted, points)).map { index, pair in
                Pin(id: index, point: pair.1, hex: pair.0.hex, name: pair.0.name, nameHex: pair.0.hex)
            }
            isLoading = false
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        ToastManager.shared.show(message, icon: "exclamationmark.triangle.fill")
        dismiss()
    }
}

#Preview {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500)).image { ctx in
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemOrange, .systemPurple]
        for (i, c) in colors.enumerated() {
            c.setFill()
            ctx.fill(CGRect(x: 0, y: CGFloat(i) * 100, width: 400, height: 100))
        }
    }
    return NavigationStack {
        PhotoPinsPage(image: image, onAdd: { _ in })
    }
}
