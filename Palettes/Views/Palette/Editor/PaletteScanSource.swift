//
//  PaletteScanSource.swift
//  Palettes
//
//  The add panel's Scan source. Without a photo: a well with Camera and
//  Library buttons. With one: the photo across the sheet's width, Remove (the
//  photo and the colors it added) and Pick Colors (see PhotoPreview), which opens the
//  full-screen picker (PalettePhotoPicker). A new photo's colors go into the
//  palette by themselves (see PaletteScanSession); this view only shows the
//  photo, moves the colors on it and takes it away.
//

import SwiftUI
import PhotosUI

struct PaletteScanSource: View {
    /// Owned by the panel, so the photo, its points and a load in flight
    /// survive switching sources.
    @ObservedObject var session: PaletteScanSession
    let draft: PaletteDraft
    /// The colors moved in the picker, with their new values.
    var onPicked: ([PaletteColor]) -> Void
    /// The photo was removed; its colors come out of the palette (with Undo).
    var onRemovePhoto: (PaletteScanSession.Removed) -> Void

    /// What the picker opens with, fixed when it is presented.
    private struct PickerInput: Identifiable {
        let id = UUID()
        let image: UIImage
        let colors: [PaletteColor]
        let points: [UUID: CGPoint]
    }

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCapture = false
    @State private var showChangeDialog = false
    @State private var pickerInput: PickerInput?
    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    /// The picker shows only the photo's own colors, so it needs at least one.
    private var canPick: Bool {
        !session.isLoading && session.sampler != nil && !session.photoColors(in: draft.colors).colors.isEmpty
    }

    var body: some View {
        Group {
            if let image = session.image {
                photoState(image)
            } else {
                emptyState
            }
        }
        .onAppear {
            if !didAcknowledgeTrueToneWarning { showTrueToneAlert = true }
        }
        .alert("Turn Off True Tone", isPresented: $showTrueToneAlert) {
            Button("Got It") { didAcknowledgeTrueToneWarning = true }
        } message: {
            Text(ScanPicker.trueToneMessage)
        }
        .photosPicker(isPresented: $showLibrary, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(image: $cameraImage, didCapture: $didCapture, isPresented: $showCamera)
        }
        .fullScreenCover(item: $pickerInput) { input in
            PalettePhotoPicker(
                image: input.image,
                sampler: session.sampler,
                colors: input.colors,
                points: input.points
            ) { picked, points in
                session.record(points)
                if !picked.isEmpty { onPicked(picked) }
            }
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
            if let photo = cameraImage { session.load(photo: photo) }
            cameraImage = nil
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            photosPickerItem = nil
            session.load(item: item)
        }
    }

    // MARK: - Photo

    private func photoState(_ image: UIImage) -> some View {
        // The photo across the sheet's width, filling the room it's given.
        PhotoPreview(
            image: image,
            isLoading: session.isLoading,
            canPick: canPick,
            onPick: openPicker,
            onRemove: {
                if let removed = session.removePhoto() { onRemovePhoto(removed) }
            },
            onChangePhoto: { showChangeDialog = true }
        )
    }

    private func openPicker() {
        guard canPick, let image = session.image else { return }
        let photo = session.photoColors(in: draft.colors)
        pickerInput = PickerInput(image: image, colors: photo.colors, points: photo.points)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.clear)
                    .liquidGlass(.regular, in: .rect(cornerRadius: 20))

                if session.isLoading {
                    ProgressView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Take or choose a photo to pull its colors")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                if Self.cameraAvailable {
                    sourceButton("Camera", symbol: "camera.fill") { showCamera = true }
                }
                sourceButton("Library", symbol: "photo.on.rectangle") { showLibrary = true }
            }
        }
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        PhotoSourceButton(title: title, symbol: symbol, action: action)
            .disabled(session.isLoading)
    }
}
