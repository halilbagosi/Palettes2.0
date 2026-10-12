//
//  PhotoPinsSession.swift
//  Palettes
//
//  The Scan source's state, owned by the add panel so it outlives the source
//  view: the chosen photo, a photo still loading, and the pins with their
//  dragged positions. Leaving Scan and coming back keeps all of it; nothing is
//  extracted twice.
//

import Combine
import SwiftUI
import PhotosUI

struct PhotoPin: Identifiable, Equatable {
    let id: Int
    var point: CGPoint
    var hex: String
    /// The name belongs to `nameHex`; it is refreshed when a drag ends.
    var name: String
    var nameHex: String
}

@MainActor
final class PhotoPinsSession: ObservableObject {
    @Published private(set) var image: UIImage?
    /// A photo is being decoded.
    @Published private(set) var isLoadingPhoto = false
    @Published var pins: [PhotoPin] = []
    /// The photo is shown and its colors are being found.
    @Published private(set) var isExtracting = false
    private(set) var sampler: ImageColorExtractor.PixelSampler?

    private var loadTask: Task<Void, Never>?
    private static let longSide: CGFloat = 2048

    /// A library photo is decoded off the main actor, straight to a 2048 px
    /// thumbnail. The load is the session's, not the view's, so it finishes
    /// even if the user switches sources meanwhile.
    func load(item: PhotosPickerItem) {
        let longSide = Self.longSide
        start {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await Task.detached { UIImage.downsampled(from: data, longSide: longSide) }.value
        }
    }

    func load(photo: UIImage) {
        let longSide = Self.longSide
        start { photo.downsampled(longSide: longSide) }
    }

    /// Drops the photo and its pins.
    func clear() {
        loadTask?.cancel()
        image = nil
        pins = []
        sampler = nil
        isExtracting = false
        isLoadingPhoto = false
    }

    private func start(_ produce: @escaping () async -> UIImage?) {
        loadTask?.cancel()
        isLoadingPhoto = true
        loadTask = Task {
            let produced = await produce()
            guard !Task.isCancelled else { return }
            isLoadingPhoto = false
            if let produced {
                image = produced
                pins = []
                sampler = nil
            } else {
                ToastManager.shared.show("Couldn't open that photo", icon: "exclamationmark.triangle.fill")
            }
        }
    }

    /// Finds the photo's colors and where each sits, once per photo. Safe to
    /// call whenever the pins view appears; does nothing if the pins exist.
    func extractIfNeeded() async {
        guard let image, pins.isEmpty else { return }
        isExtracting = true
        // Let the spinner draw before the work starts.
        try? await Task.sleep(for: .milliseconds(50))
        // The view went away (or the photo changed) before we began.
        guard !Task.isCancelled, self.image === image else { return }
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
                PhotoPin(id: index, point: pair.1, hex: pair.0.hex, name: pair.0.name, nameHex: pair.0.hex)
            }
            isExtracting = false
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        ToastManager.shared.show(message, icon: "exclamationmark.triangle.fill")
        clear()
    }
}
