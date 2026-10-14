//
//  ScanSession.swift
//  Palettes
//
//  New Color's photo: the picked image, where its color was last picked, and
//  the color there.
//

import Combine
import SwiftUI
import PhotosUI
import UIKit

/// The chosen photo and the marker on it, held by the color editor so the
/// photo and a load still in flight outlive the full-screen picker.
@MainActor
final class ScanSession: ObservableObject {
    /// Shown once per install the first time a Scan view appears.
    static let trueToneMessage = "For accurate color scanning, turn off True Tone in Settings → Display & Brightness. True Tone adjusts your screen's warmth, which can affect how scanned colors appear."

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

    /// Makes the photo current; the host picks the starting color from it.
    private func commit(_ raw: UIImage) {
        let small = raw.downsampled(longSide: 2048)
        guard let sampler = ImageColorExtractor.PixelSampler(image: small) else {
            fail(AppError.imageProcessingFailed.localizedDescription)
            return
        }
        image = small
        self.sampler = sampler
        point = CGPoint(x: 0.5, y: 0.5)
        sampledColor = nil
        needsDelivery = true
    }

    private func fail(_ message: String) {
        ToastManager.shared.show(message, icon: "exclamationmark.triangle.fill")
    }
}

