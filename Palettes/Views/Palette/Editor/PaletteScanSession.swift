//
//  PaletteScanSession.swift
//  Palettes
//
//  The Scan source's state, owned by the add panel so it outlives the source
//  view: the chosen photo, a load in flight, and where each palette color was
//  picked on the photo. A new photo's colors go straight into the palette
//  (replacing the previous photo's); the full-screen picker then moves them.
//  Leaving Scan and coming back keeps all of it; nothing is extracted twice.
//

import Combine
import SwiftUI
import PhotosUI

@MainActor
final class PaletteScanSession: ObservableObject {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    /// Colors found in a new photo, for the editor to put in the palette in
    /// place of the previous photo's colors (`replacing`).
    struct Delivery: Equatable {
        let colors: [PaletteColor]
        let replacing: Set<UUID>
    }

    @Published private(set) var image: UIImage?
    /// A photo is being decoded or its colors found.
    @Published private(set) var isLoading = false
    /// Set when a photo's colors are found; the panel hands it to the editor
    /// and calls `takeDelivery()`.
    @Published private(set) var delivery: Delivery?
    private(set) var sampler: ImageColorExtractor.PixelSampler?

    /// Where each palette color sits on the photo, by the color's id: where it
    /// was found, or where it was last picked.
    private var points: [UUID: CGPoint] = [:]
    /// The colors the current photo put in the palette.
    private var photoColorIDs: Set<UUID> = []

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

    /// Waits for the photo load, and the extraction that follows it, to finish.
    func waitForLoad() async {
        await loadTask?.value
    }

    func takeDelivery() {
        delivery = nil
    }

    /// The palette's colors that came from this photo (in palette order; not
    /// those added by Pick, Library or Harmony), with where each sits on it:
    /// where it was found or last picked.
    func photoColors(in palette: [PaletteColor]) -> (colors: [PaletteColor], points: [UUID: CGPoint]) {
        let colors = palette.filter { photoColorIDs.contains($0.id) && points[$0.id] != nil }
        return (colors, points.filter { id, _ in colors.contains { $0.id == id } })
    }

    /// What Remove took away, so Undo can put it back.
    struct Removed {
        fileprivate let image: UIImage
        fileprivate let sampler: ImageColorExtractor.PixelSampler?
        fileprivate let points: [UUID: CGPoint]
        /// The colors the photo had put in the palette.
        let colorIDs: Set<UUID>
    }

    /// Drops the photo; the caller takes `colorIDs` out of the palette.
    func removePhoto() -> Removed? {
        guard let image else { return nil }
        loadTask?.cancel()
        let removed = Removed(image: image, sampler: sampler, points: points, colorIDs: photoColorIDs)
        self.image = nil
        sampler = nil
        points = [:]
        photoColorIDs = []
        isLoading = false
        return removed
    }

    /// Undo of `removePhoto()`, unless another photo has been chosen since.
    func restore(_ removed: Removed) {
        guard image == nil, !isLoading else { return }
        image = removed.image
        sampler = removed.sampler
        points = removed.points
        photoColorIDs = removed.colorIDs
    }

    /// Remembers where the colors were picked, for the next time the picker opens.
    func record(_ picked: [UUID: CGPoint]) {
        points.merge(picked) { _, new in new }
    }

    private func start(_ produce: @escaping () async -> UIImage?) {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            let produced = await produce()
            guard !Task.isCancelled else { return }
            guard let produced else {
                isLoading = false
                ToastManager.shared.show("Couldn't open that photo", icon: "exclamationmark.triangle.fill")
                return
            }
            // Let the spinner draw over the new photo before the work starts.
            image = produced
            sampler = nil
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            extract(from: produced)
            isLoading = false
        }
    }

    /// Finds the photo's colors and where each sits, and queues them for the palette.
    private func extract(from image: UIImage) {
        guard let sampler = ImageColorExtractor.PixelSampler(image: image) else {
            fail(AppError.imageProcessingFailed.localizedDescription)
            return
        }
        do {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 6)
            let colors = extracted.compactMap { item in
                Color(hex: item.hex).map { PaletteColor(color: $0, hex: item.hex, name: item.name) }
            }
            guard !colors.isEmpty else {
                fail("Couldn't find any colors in that photo")
                return
            }
            let located = PhotoPinLocator.locate(hexes: colors.map(\.hex), in: sampler)
            self.sampler = sampler
            delivery = Delivery(colors: colors, replacing: photoColorIDs)
            photoColorIDs = Set(colors.map(\.id))
            points = Dictionary(uniqueKeysWithValues: zip(colors.map(\.id), located))
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        ToastManager.shared.show(message, icon: "exclamationmark.triangle.fill")
        image = nil
        sampler = nil
        points = [:]
        photoColorIDs = []
    }
}
