//
//  PhotoPreview.swift
//  Palettes
//
//  A picked photo with Remove and Pick under it, shared by New Color
//  and the palette editor's Scan source. The buttons are the same rounded
//  glass buttons as Scan's Camera and Library.
//

import SwiftUI

struct PhotoPreview: View {
    let image: UIImage?
    var isLoading = false
    /// A fixed height for the photo; nil fills what the parent offers.
    var height: CGFloat? = nil
    var canPick = true
    var onPick: () -> Void
    var onRemove: () -> Void
    /// When set, a "Change Photo" capsule sits in the photo's corner.
    var onChangePhoto: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            // The photo fills the area, cropped at the edges.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: height == nil ? .infinity : nil)
                .frame(height: height)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .accessibilityHidden(true)
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.clear)
                        .liquidGlass(.regular, in: .rect(cornerRadius: 20))
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    if isLoading { ProgressView() }
                }
                .overlay(alignment: .topTrailing) {
                    if let onChangePhoto {
                        Button(action: onChangePhoto) {
                            Label("Change Photo", systemImage: "photo.on.rectangle")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .liquidGlass(.interactive, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .padding(8)
                        .disabled(isLoading)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { if canPick { onPick() } }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Photo")

            HStack(spacing: 12) {
                PhotoSourceButton(title: "Remove", symbol: "trash", role: .destructive, action: onRemove)
                    .disabled(isLoading)
                    .accessibilityHint("Removes the photo")
                PhotoSourceButton(title: "Pick", symbol: "eyedropper", action: onPick)
                    .disabled(!canPick)
            }
        }
    }
}

/// Scan's Camera / Library button: a label on interactive glass, rounded 14.
struct PhotoSourceButton: View {
    let title: String
    let symbol: String
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(role == .destructive ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .liquidGlass(.interactive, in: .rect(cornerRadius: 14))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
