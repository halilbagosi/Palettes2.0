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
    /// Owned by the panel, so the photo survives switching sources.
    @Binding var image: UIImage?
    var onAdd: ([PaletteColor]) -> Void

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didCapture = false
    @State private var showChangeDialog = false
    @State private var isLoading = false
    @State private var loadTask: Task<Void, Never>?
    @State private var showTrueToneAlert = false
    @AppStorage("didAcknowledgeTrueToneWarning") private var didAcknowledgeTrueToneWarning = false

    private static let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    private static let longSide: CGFloat = 2048

    var body: some View {
        Group {
            if let image {
                PhotoPinsView(
                    image: image,
                    onAdd: onAdd,
                    onChangePhoto: { showChangeDialog = true },
                    onFail: { self.image = nil }
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
            if let photo = cameraImage { use(photo) }
            cameraImage = nil
        }
        .onChange(of: photosPickerItem) { _, item in
            guard let item else { return }
            photosPickerItem = nil
            use(item)
        }
        .onDisappear { loadTask?.cancel() }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.07))

                if isLoading {
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
        .disabled(isLoading)
    }

    // MARK: - Loading

    /// A library photo is decoded off the main actor, straight to a 2048 px
    /// thumbnail.
    private func use(_ item: PhotosPickerItem) {
        let longSide = Self.longSide
        start {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await Task.detached { UIImage.downsampled(from: data, longSide: longSide) }.value
        }
    }

    private func use(_ photo: UIImage) {
        start { photo.downsampled(longSide: Self.longSide) }
    }

    private func start(_ produce: @escaping () async -> UIImage?) {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            let produced = await produce()
            guard !Task.isCancelled else { return }
            isLoading = false
            if let produced {
                image = produced
            } else {
                ToastManager.shared.show("Couldn't open that photo", icon: "exclamationmark.triangle.fill")
            }
        }
    }
}
