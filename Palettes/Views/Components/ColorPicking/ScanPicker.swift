//
//  ScanPicker.swift
//  Palettes
//
//  The color picker's Scan mode: take or choose a photo, then drag one marker
//  over it (or touch anywhere on it) to pick the color underneath. The photo
//  is shown aspect-fit so the whole picture is visible and the marker always
//  maps 1:1 onto a pixel; touches outside the picture clamp to its edge.
//

import Combine
import SwiftUI
import PhotosUI
import UIKit

/// Pure geometry for the Scan marker, kept apart from SwiftUI so it can be
/// tested. Points are normalized image coordinates (0…1, top-left origin);
/// `rect` is where the image sits in the view (`PhotoLoupeGeometry.imageRect`).
enum ScanPickerGeometry {
    /// How far from the marker's center a touch still grabs it (half of a 44 pt target).
    static let grabRadius: CGFloat = 22

    /// True when a touch that began at `location` landed on the marker.
    static func grabsMarker(at location: CGPoint, marker: CGPoint, in rect: CGRect) -> Bool {
        let center = PhotoPinGeometry.position(of: marker, in: rect)
        return hypot(location.x - center.x, location.y - center.y) <= grabRadius
    }

    /// The image point under a touch, clamped to the image's edge.
    static func point(at location: CGPoint, in rect: CGRect) -> CGPoint {
        let clamped = CGPoint(
            x: min(max(location.x, rect.minX), rect.maxX),
            y: min(max(location.y, rect.minY), rect.maxY)
        )
        return PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped)
    }
}

/// The chosen photo and the marker on it. Lives outside `ScanPicker` so the
/// photo survives the picker being removed (e.g. while the keyboard is up).
@MainActor
final class ScanSession: ObservableObject {
    @Published private(set) var image: UIImage?
    /// The marker, in normalized image coordinates.
    @Published var point = CGPoint(x: 0.5, y: 0.5)
    @Published private(set) var isLoading = false
    private(set) var sampler: ImageColorExtractor.PixelSampler?

    /// Downsamples the photo, finds its dominant color and where it sits, and
    /// makes it the current photo. Returns the dominant color's RGB (0…255),
    /// or nil if it failed or was cancelled (the previous photo stays).
    func prepare(_ raw: UIImage) async -> (r: Double, g: Double, b: Double)? {
        isLoading = true
        defer { isLoading = false }
        // Let the spinner draw before the work starts.
        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled else { return nil }

        let small = raw.downsampled(longSide: 2048)
        guard let sampler = ImageColorExtractor.PixelSampler(image: small) else {
            fail(AppError.imageProcessingFailed.localizedDescription)
            return nil
        }
        do {
            let rgb = try ImageColorExtractor.extractDominantRGB(from: small)
            let hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: rgb.b)
            let located = PhotoPinLocator.locate(hexes: [hex], in: sampler).first
            guard !Task.isCancelled else { return nil }
            image = small
            self.sampler = sampler
            point = located ?? CGPoint(x: 0.5, y: 0.5)
            return rgb
        } catch {
            fail(error.localizedDescription)
            return nil
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
    /// A photo waiting to be prepared; the task below handles it.
    @State private var pending: UIImage?

    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false

    /// The finger on the photo: where the marker was when it went down, and
    /// whether the finger grabbed the marker (moves relative) or landed
    /// elsewhere (the marker jumps under it).
    @State private var drag: (origin: CGPoint, grabbed: Bool)?

    private static let markerSize: CGFloat = 30
    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        VStack(spacing: 12) {
            photoArea
            if session.image == nil {
                sourceButtons
            }
        }
        .onAppear {
            if !didAcknowledgeTrueToneWarning { showTrueToneAlert = true }
        }
        .alert("Turn Off True Tone", isPresented: $showTrueToneAlert) {
            Button("Got It") { didAcknowledgeTrueToneWarning = true }
        } message: {
            Text("For accurate color scanning, turn off True Tone in Settings → Display & Brightness. True Tone adjusts your screen's warmth, which can affect how scanned colors appear.")
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
            if let cameraImage { pending = cameraImage }
        }
        .task(id: photosPickerItem) {
            guard let item = photosPickerItem else { return }
            let data = try? await item.loadTransferable(type: Data.self)
            guard !Task.isCancelled else { return }
            photosPickerItem = nil
            if let data, let image = UIImage(data: data) { pending = image }
        }
        .task(id: pending.map(ObjectIdentifier.init)) {
            guard let raw = pending else { return }
            let rgb = await session.prepare(raw)
            guard !Task.isCancelled else { return }
            pending = nil
            if let rgb { onPick(ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)) }
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
            let rect = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: geo.size)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityLabel("Photo")
                marker(in: rect)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(in: rect))
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

    private func marker(in rect: CGRect) -> some View {
        let lifted = drag != nil
        return Circle()
            .fill(color)
            .frame(width: Self.markerSize, height: Self.markerSize)
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .scaleEffect(lifted && !reduceMotion ? 1.15 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.2), value: lifted)
            .position(PhotoPinGeometry.position(of: session.point, in: rect))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sample point")
            .accessibilityValue(ColorAdjustment.hexString(from: color))
            .accessibilityHint("Swipe up or down to move it right or left across the photo.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: place(PhotoPinGeometry.nudged(session.point, by: 1))
                case .decrement: place(PhotoPinGeometry.nudged(session.point, by: -1))
                @unknown default: break
                }
            }
    }

    private func dragGesture(in rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if drag == nil {
                    let grabbed = ScanPickerGeometry.grabsMarker(at: value.startLocation, marker: session.point, in: rect)
                    drag = (session.point, grabbed)
                }
                guard let drag else { return }
                let new = drag.grabbed
                    ? PhotoPinGeometry.moved(from: drag.origin, by: value.translation, in: rect)
                    : ScanPickerGeometry.point(at: value.location, in: rect)
                place(new)
            }
            .onEnded { _ in drag = nil }
    }

    /// Moves the marker and reports the color under it, 1:1 with no animation.
    private func place(_ point: CGPoint) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            session.point = point
            guard let sampler = session.sampler else { return }
            let rgb = sampler.color(at: point, radius: 2)
            onPick(ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b))
        }
    }

    // MARK: - Camera / Library

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
