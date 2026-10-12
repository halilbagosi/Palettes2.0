//
//  PhotoPinsView.swift
//  Palettes
//
//  The add panel's Scan source once a photo is chosen. Colors are pulled from
//  the photo automatically, then the photo is shown with a pin where each one
//  was found. Dragging a pin picks a different color; the strip under the
//  photo follows live. "+ Add N" hands the colors to the editor, which appends
//  them. The photo and its pins are drag surfaces, so this view must never sit
//  inside a scroll view.
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

struct PhotoPinsView: View {
    let image: UIImage
    @ObservedObject var session: PhotoPinsSession
    let onAdd: ([PaletteColor]) -> Void
    /// Opens the Camera / Library choice for another photo.
    let onChangePhoto: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pins being dragged, each with where it was when its finger went down.
    /// Keyed per pin so two fingers on two pins don't share state.
    @State private var dragOrigins: [Int: CGPoint] = [:]
    /// Pins released, for the release haptic.
    @State private var releaseCount = 0

    private static let pinSize: CGFloat = 30
    private static let space = "photoPins"

    private var colors: [PaletteColor] {
        var seen = Set<String>()
        return session.pins.compactMap { pin in
            guard seen.insert(pin.hex.uppercased()).inserted, let color = Color(hex: pin.hex) else { return nil }
            let name = pin.nameHex == pin.hex ? pin.name : ColorNamer.name(forHex: pin.hex)
            return PaletteColor(color: color, hex: pin.hex, name: name)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let rect = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: geo.size)
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: rect.width, height: rect.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel("Photo")

                    ForEach(Array(session.pins.enumerated()), id: \.element.id) { offset, pin in
                        pinView(pin, number: offset + 1, rect: rect)
                    }

                    if session.isExtracting || session.isLoadingPhoto {
                        ProgressView()
                    }
                }
                .coordinateSpace(name: Self.space)
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onChangePhoto) {
                    Label("Change Photo", systemImage: "photo.on.rectangle")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .padding(6)
            }

            PaletteStrip(colors: session.pins.compactMap { Color(hex: $0.hex) }, height: 32, cornerRadius: 10)
                .accessibilityHidden(true)

            Button { onAdd(colors) } label: {
                Label(colors.isEmpty ? "Add" : "Add \(colors.count)", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .glassButton(prominent: true)
            .controlSize(.large)
            .disabled(colors.isEmpty)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: releaseCount)
        // Room for a pin to hang over the photo's edge.
        .padding(.horizontal, Self.pinSize / 2)
        .padding(.top, Self.pinSize / 2 - 4)
    }

    // MARK: - Pin

    private func pinView(_ pin: PhotoPin, number: Int, rect: CGRect) -> some View {
        let lifted = dragOrigins[pin.id] != nil
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
                if dragOrigins[id] == nil, let start = session.pins.first(where: { $0.id == id })?.point {
                    dragOrigins[id] = start
                }
                guard let origin = dragOrigins[id] else { return }
                // The pin tracks the finger 1:1, so nothing here animates.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    place(id, at: PhotoPinGeometry.moved(from: origin, by: value.translation, in: rect))
                }
            }
            .onEnded { _ in
                dragOrigins[id] = nil
                releaseCount += 1
                refreshName(of: id)
            }
    }

    // MARK: - Pins

    /// Moves a pin and re-reads the color under it.
    private func place(_ id: Int, at point: CGPoint) {
        guard let i = session.pins.firstIndex(where: { $0.id == id }) else { return }
        session.pins[i].point = point
        if let sampler = session.sampler {
            let rgb = sampler.color(at: point, radius: 2)
            session.pins[i].hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: rgb.b)
        }
    }

    private func refreshName(of id: Int) {
        guard let i = session.pins.firstIndex(where: { $0.id == id }), session.pins[i].nameHex != session.pins[i].hex else { return }
        session.pins[i].name = ColorNamer.name(forHex: session.pins[i].hex)
        session.pins[i].nameHex = session.pins[i].hex
    }

    private func nudge(_ id: Int, by direction: Int) {
        guard let pin = session.pins.first(where: { $0.id == id }) else { return }
        place(id, at: PhotoPinGeometry.nudged(pin.point, by: direction))
        refreshName(of: id)
        if let moved = session.pins.first(where: { $0.id == id }) {
            UIAccessibility.post(notification: .announcement, argument: moved.name)
        }
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
    let session = PhotoPinsSession()
    return PhotoPinsView(image: image, session: session, onAdd: { _ in }, onChangePhoto: {})
        .frame(height: 300)
        .padding()
}
