//
//  PaletteScanSource.swift
//  Palettes
//
//  The add panel's Scan source. Without a photo: a well with Camera and
//  Library buttons. With one: the photo with draggable pins, a live mini strip
//  and "+ Add N" (PhotoPinsView). It always appends; from an empty palette,
//  that is the same as filling it.
//

import SwiftUI
import PhotosUI

struct PaletteScanSource: View {
    /// Owned by the panel, so the photo, its pins and a load in flight survive
    /// switching sources.
    @ObservedObject var session: PhotoPinsSession
    var onAdd: ([PaletteColor]) -> Void

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCapture = false
    @State private var showChangeDialog = false
    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        Group {
            if let image = session.image {
                PhotoPinsView(
                    image: image,
                    session: session,
                    onAdd: onAdd,
                    onChangePhoto: { showChangeDialog = true }
                )
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

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.07))

                if session.isLoadingPhoto {
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

    /// Glass rule: these buttons sit inside the add panel's glass card, so they
    /// keep a tint (`panelWell`), not glass-on-glass. ScanPicker's identical
    /// buttons sit on a plain background and use interactive glass.
    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .panelWell(in: .rect(cornerRadius: 14))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tint(.primary)
        .disabled(session.isLoadingPhoto)
    }
}
