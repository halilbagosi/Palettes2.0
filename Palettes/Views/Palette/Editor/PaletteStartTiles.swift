//
//  PaletteStartTiles.swift
//  Palettes
//
//  What an empty palette offers instead of a list: four ways to start, as a
//  2×2 grid of tiles, and a quiet "Start Blank" under them. PaletteEditor owns
//  what each one does.
//

import SwiftUI

struct PaletteStartTiles: View {
    /// Hidden when the library is empty.
    var showsLibrary: Bool
    /// Only where the Generate tab exists.
    var showsGenerate: Bool
    var cameraAvailable: Bool
    var onChoosePhoto: () -> Void
    var onTakePhoto: () -> Void
    var onLibrary: () -> Void
    var onOneColor: () -> Void
    var onGenerate: () -> Void
    var onStartBlank: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: columns, spacing: 12) {
                photoTile

                if showsLibrary {
                    Button(action: onLibrary) {
                        StartTile(
                            title: "From My Colors",
                            subtitle: "Pick from colors you've saved",
                            symbol: "square.grid.2x2.fill",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(StartTileButtonStyle())
                }

                Button(action: onOneColor) {
                    StartTile(
                        title: "From One Color",
                        subtitle: "Build around a single color",
                        symbol: "circle.lefthalf.filled",
                        tint: .pink
                    )
                }
                .buttonStyle(StartTileButtonStyle())

                if showsGenerate {
                    Button(action: onGenerate) {
                        StartTile(
                            title: "Generate with AI",
                            subtitle: "Opens the Generate tab",
                            symbol: "sparkles",
                            tint: .purple,
                            showsLeavesArrow: true
                        )
                    }
                    .buttonStyle(StartTileButtonStyle())
                }
            }

            Button("Start Blank", action: onStartBlank)
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var photoTile: some View {
        let tile = StartTile(
            title: "From a Photo",
            subtitle: "Pull colors from a picture",
            symbol: "photo.fill",
            tint: .orange
        )
        if cameraAvailable {
            Menu {
                Button("Choose Photo", systemImage: "photo.on.rectangle", action: onChoosePhoto)
                Button("Take Photo", systemImage: "camera", action: onTakePhoto)
            } label: {
                tile
            }
            .buttonStyle(StartTileButtonStyle())
        } else {
            Button(action: onChoosePhoto) { tile }
                .buttonStyle(StartTileButtonStyle())
        }
    }
}

private struct StartTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    /// Generate leaves the editor for another tab.
    var showsLeavesArrow = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(tint.gradient, in: Circle())
                    .accessibilityHidden(true)

                Spacer(minLength: 0)

                if showsLeavesArrow {
                    Image(systemName: "arrow.up.forward")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

private struct StartTileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .snappy, value: configuration.isPressed)
    }
}

#Preview {
    List {
        Section {
            PaletteStartTiles(
                showsLibrary: true,
                showsGenerate: true,
                cameraAvailable: true,
                onChoosePhoto: {}, onTakePhoto: {}, onLibrary: {},
                onOneColor: {}, onGenerate: {}, onStartBlank: {}
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }
}
