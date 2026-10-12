//
//  ScanPicker.swift
//  Palettes
//
//  The color picker's Scan mode: take or choose a photo, then drag one marker
//  over it (or touch anywhere on it) to pick the color underneath. The photo
//  fills the area (cropped at the edges); the marker and touches are kept to
//  the part that is shown, so the marker always maps 1:1 onto a visible pixel.
//

import Combine
import SwiftUI
import PhotosUI
import UIKit

/// Pure geometry for the Scan marker, kept apart from SwiftUI so it can be
/// tested. Points are normalized image coordinates (0…1, top-left origin).
///
/// The photo is shown aspect-FILL: the "fill rect" is where the whole image
/// sits (larger than the view on one axis, so its edges are cropped), and the
/// "visible rect" is the part of it the view actually shows. The marker and
/// every touch are clamped to the visible rect.
enum ScanPickerGeometry {
    /// How far from the marker's center a touch still grabs it (half of a 44 pt target).
    static let grabRadius: CGFloat = 22

    /// Where an image of `imageSize` sits when scaled to cover `viewSize`,
    /// centered. Its origin is negative on the cropped axis.
    static func fillRect(imageSize: CGSize, in viewSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (viewSize.width - size.width) / 2, y: (viewSize.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    /// The part of the fill rect the view shows.
    static func visibleRect(fill: CGRect, in viewSize: CGSize) -> CGRect {
        fill.intersection(CGRect(origin: .zero, size: viewSize))
    }

    /// True when a touch that began at `location` landed on the marker.
    static func grabsMarker(at location: CGPoint, marker: CGPoint, fill: CGRect) -> Bool {
        let center = PhotoPinGeometry.position(of: marker, in: fill)
        return hypot(location.x - center.x, location.y - center.y) <= grabRadius
    }

    /// The image point under a touch, clamped to the visible rect.
    static func point(at location: CGPoint, fill: CGRect, visible: CGRect) -> CGPoint {
        PhotoLoupeGeometry.normalizedPoint(in: fill, at: clamp(location, to: visible))
    }

    /// Where a marker that started at `origin` ends up after the finger moved
    /// by `translation`, clamped to the visible rect.
    static func moved(from origin: CGPoint, by translation: CGSize, fill: CGRect, visible: CGRect) -> CGPoint {
        let start = PhotoPinGeometry.position(of: origin, in: fill)
        let target = CGPoint(x: start.x + translation.width, y: start.y + translation.height)
        return point(at: target, fill: fill, visible: visible)
    }

    /// `point` itself when it is shown; otherwise the nearest shown point.
    static func clampedIntoVisible(_ point: CGPoint, fill: CGRect, visible: CGRect) -> CGPoint {
        self.point(at: PhotoPinGeometry.position(of: point, in: fill), fill: fill, visible: visible)
    }

    private static func clamp(_ p: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(p.x, rect.minX), rect.maxX), y: min(max(p.y, rect.minY), rect.maxY))
    }
}

/// The chosen photo and the marker on it. Lives outside `ScanPicker` so the
/// photo, and a load still in flight, survive the picker being removed
/// (e.g. while the keyboard is up).
@MainActor
final class ScanSession: ObservableObject {
    @Published private(set) var image: UIImage?
    /// The marker, in normalized image coordinates.
    @Published private(set) var point = CGPoint(x: 0.5, y: 0.5)
    /// The color last read under the marker.
    @Published private(set) var sampledColor: Color?
    @Published private(set) var isLoading = false
    /// A new photo has been loaded and its starting color not yet handed to the host.
    @Published var needsDelivery = false
    private(set) var sampler: ImageColorExtractor.PixelSampler?

    private var loadTask: Task<Void, Never>?
    /// Bumped by every load; only the newest one may touch `isLoading` or the photo.
    private var loadCounter = 0

    /// Loads a photo from the library. The bytes are decoded off the main
    /// actor, straight to a 2048 px thumbnail.
    func load(item: PhotosPickerItem) {
        start {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await Task.detached { UIImage.downsampled(from: data, longSide: 2048) }.value
        }
    }

    /// Loads a camera photo (downsampled before use).
    func load(image: UIImage) {
        start { image }
    }

    /// Drops the photo (and any load still in flight).
    func clear() {
        loadTask?.cancel()
        loadCounter += 1
        isLoading = false
        needsDelivery = false
        image = nil
        sampler = nil
        sampledColor = nil
        point = CGPoint(x: 0.5, y: 0.5)
    }

    /// Moves the marker and reads the color under it.
    func sample(at point: CGPoint) {
        self.point = point
        if let sampler {
            let rgb = sampler.color(at: point, radius: 2)
            sampledColor = ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)
        }
    }

    private func start(_ produce: @escaping () async -> UIImage?) {
        loadTask?.cancel()
        loadCounter += 1
        let token = loadCounter
        isLoading = true
        loadTask = Task {
            let produced = await produce()
            // Let the spinner draw before the work starts.
            try? await Task.sleep(for: .milliseconds(50))
            // A newer load owns the state now (and `isLoading`).
            guard token == loadCounter else { return }
            defer { isLoading = false }
            guard let produced else {
                fail(AppError.imageProcessingFailed.localizedDescription)
                return
            }
            commit(produced)
        }
    }

    /// Finds the photo's dominant color and where it sits, and makes the photo current.
    private func commit(_ raw: UIImage) {
        let small = raw.downsampled(longSide: 2048)
        guard let sampler = ImageColorExtractor.PixelSampler(image: small) else {
            fail(AppError.imageProcessingFailed.localizedDescription)
            return
        }
        do {
            let rgb = try ImageColorExtractor.extractDominantRGB(from: small)
            let hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: rgb.b)
            image = small
            self.sampler = sampler
            point = PhotoPinLocator.locate(hexes: [hex], in: sampler).first ?? CGPoint(x: 0.5, y: 0.5)
            sampledColor = ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)
            needsDelivery = true
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        ToastManager.shared.show(message, icon: "exclamationmark.triangle.fill")
    }
}

struct ScanPicker: View {
    @Binding var color: Color
    @ObservedObject var session: ScanSession
    var height: CGFloat = 180
    var onPick: (Color) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCapture = false
    @State private var showChangeDialog = false

    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false

    /// The finger on the photo: where the marker was when it went down, and
    /// whether the finger grabbed the marker (moves relative) or landed
    /// elsewhere (the marker jumps under it). A gesture state, so a cancelled
    /// touch can't leave the marker lifted or a stale origin behind.
    private struct Drag: Equatable {
        var origin: CGPoint
        var grabbed: Bool
    }
    @GestureState private var drag: Drag?
    /// Marker releases, for the release haptic (same as a photo pin's).
    @State private var releaseCount = 0

    /// Shown once per install the first time a Scan view appears; also used by
    /// the palette add panel's Scan source.
    static let trueToneMessage = "For accurate color scanning, turn off True Tone in Settings → Display & Brightness. True Tone adjusts your screen's warmth, which can affect how scanned colors appear."

    private static let markerSize: CGFloat = 30
    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        VStack(spacing: 12) {
            photoArea
            if session.image == nil {
                sourceButtons
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: releaseCount)
        .onAppear {
            if !didAcknowledgeTrueToneWarning { showTrueToneAlert = true }
        }
        .alert("Turn Off True Tone", isPresented: $showTrueToneAlert) {
            Button("Got It") { didAcknowledgeTrueToneWarning = true }
        } message: {
            Text(Self.trueToneMessage)
        }
        .photosPicker(isPresented: $showLibrary, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage, didCapture: $didCapture, isPresented: $showCamera)
        }
        .confirmationDialog("Change Photo", isPresented: $showChangeDialog) {
            if Self.cameraAvailable {
                Button("Take Photo") { showCamera = true }
            }
            Button("Choose from Library") { showLibrary = true }
        }
        .onChange(of: didCapture) { _, captured in
            guard captured else { return }
            didCapture = false
            if let image = cameraImage { session.load(image: image) }
            cameraImage = nil
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            photosPickerItem = nil
            session.load(item: item)
        }
    }

    // MARK: - Photo area

    private var photoArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.clear)
                .liquidGlass(.regular, in: .rect(cornerRadius: 20))

            if let image = session.image {
                photo(image)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Take or choose a photo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .accessibilityElement(children: .combine)
            }

            if session.isLoading {
                ProgressView()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func photo(_ image: UIImage) -> some View {
        GeometryReader { geo in
            let fill = ScanPickerGeometry.fillRect(imageSize: image.size, in: geo.size)
            let visible = ScanPickerGeometry.visibleRect(fill: fill, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: fill.width, height: fill.height)
                    .position(x: fill.midX, y: fill.midY)
                    .accessibilityLabel("Photo")
                marker(fill: fill, visible: visible)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(fill: fill, visible: visible))
            // A new photo's starting point can sit in the cropped part, and a
            // resize changes what is cropped: pull the marker back into view.
            .onChange(of: session.needsDelivery, initial: true) { _, _ in
                guard session.needsDelivery else { return }
                session.needsDelivery = false
                if !settle(fill: fill, visible: visible), let color = session.sampledColor {
                    onPick(color)
                }
            }
            .onChange(of: geo.size) { _, _ in settle(fill: fill, visible: visible) }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                showChangeDialog = true
            } label: {
                Label("Change Photo", systemImage: "photo.on.rectangle")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(.interactive, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(8)
        }
    }

    private func marker(fill: CGRect, visible: CGRect) -> some View {
        let lifted = drag != nil && !reduceMotion
        let markerColor = session.sampledColor ?? color
        return Circle()
            .fill(markerColor)
            .frame(width: Self.markerSize, height: Self.markerSize)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            // Only the lift animates; the fill and position follow the finger.
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.2)) { $0.scaleEffect(lifted ? 1.15 : 1) }
            .position(PhotoPinGeometry.position(of: session.point, in: fill))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sample point")
            .accessibilityValue(ColorAdjustment.hexString(from: markerColor))
            .accessibilityHint("Swipe up or down to move it right or left across the photo.")
            .accessibilityAdjustableAction { direction in
                let step: Int
                switch direction {
                case .increment: step = 1
                case .decrement: step = -1
                @unknown default: return
                }
                place(ScanPickerGeometry.clampedIntoVisible(
                    PhotoPinGeometry.nudged(session.point, by: step), fill: fill, visible: visible))
            }
    }

    private func dragGesture(fill: CGRect, visible: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($drag) { value, state, _ in
                let current = state ?? Drag(
                    origin: session.point,
                    grabbed: ScanPickerGeometry.grabsMarker(at: value.startLocation, marker: session.point, fill: fill)
                )
                state = current
                place(current.grabbed
                    ? ScanPickerGeometry.moved(from: current.origin, by: value.translation, fill: fill, visible: visible)
                    : ScanPickerGeometry.point(at: value.location, fill: fill, visible: visible))
            }
            .onEnded { _ in releaseCount += 1 }
    }

    /// Moves the marker and reports the color under it, 1:1 with no animation.
    private func place(_ point: CGPoint) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            session.sample(at: point)
            if let sampled = session.sampledColor { onPick(sampled) }
        }
    }

    /// Pulls the marker into the visible part of the photo, re-sampling there.
    /// Returns true if it had to move.
    @discardableResult
    private func settle(fill: CGRect, visible: CGRect) -> Bool {
        let clamped = ScanPickerGeometry.clampedIntoVisible(session.point, fill: fill, visible: visible)
        guard clamped != session.point else { return false }
        place(clamped)
        return true
    }

    // MARK: - Camera / Library

    /// Dev's Camera / Library buttons: interactive glass on the plain background.
    private var sourceButtons: some View {
        HStack(spacing: 12) {
            if Self.cameraAvailable {
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .liquidGlass(.interactive, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .tint(.primary)
            }

            Button {
                showLibrary = true
            } label: {
                Label("Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .liquidGlass(.interactive, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .tint(.primary)
        }
    }
}
