//
//  SharedLinkSheet.swift
//  Palettes
//
//  What opening a shared palette or color link shows: the colors, and Save
//  or Discard. If the library already has it, Open takes its place.
//

import SwiftUI

struct SharedLinkSheet: View {
    let link: SharedLink
    /// Called after the sheet saved (or found) the item, with what to open.
    let onOpen: (SharedLinkSheet.Destination) -> Void

    enum Destination {
        case palette(UUID)
        case color(UUID)
    }

    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss

    private var colors: [Color] {
        link.swatches.map { Color(hex: $0.hex) ?? .gray }
    }

    /// The library's copy, if it already has these colors (palette) or
    /// this hex (color).
    private var existing: Destination? {
        switch link.kind {
        case .palette:
            appData.existingPalette(matching: link.swatches.map(\.hex)).map { .palette($0.id) }
        case .color:
            appData.existingColor(hex: link.swatches[0].hex).map { .color($0.id) }
        }
    }

    private var existingName: String? {
        switch existing {
        case .palette(let id): appData.palettes.first { $0.id == id }?.name
        case .color(let id): appData.colors.first { $0.id == id }?.name
        case nil: nil
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    if let existingName {
                        Label("Already in your library as \u{201C}\(existingName)\u{201D}.", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if link.kind == .palette {
                        swatchList
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .bottomActionBar { actionBar }
            .navigationTitle(link.kind == .palette ? "Shared Palette" : "Shared Color")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var hero: some View {
        switch link.kind {
        case .palette:
            VStack(alignment: .leading, spacing: 10) {
                PaletteStrip(colors: colors, height: 120, cornerRadius: 22)
                HStack(alignment: .firstTextBaseline) {
                    Text(link.name)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Spacer()
                    Text("\(link.swatches.count) \(link.swatches.count == 1 ? "color" : "colors")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        case .color:
            let swatch = link.swatches[0]
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(colors[0])
                    .frame(height: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                Text(swatch.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                HStack(spacing: 16) {
                    Text(swatch.hex)
                    Text(colors[0].rgbString)
                }
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
            }
        }
    }

    private var swatchList: some View {
        VStack(spacing: 0) {
            ForEach(Array(link.swatches.enumerated()), id: \.offset) { index, swatch in
                HStack(spacing: 12) {
                    Circle()
                        .fill(colors[index])
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    Text(swatch.name)
                        .lineLimit(1)
                    if let role = swatch.role {
                        Text(role)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    Text(swatch.hex)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                if index < link.swatches.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("Discard", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .glassButton()

            Button {
                let destination = existing ?? save()
                dismiss()
                onOpen(destination)
            } label: {
                Label(existing == nil ? "Save" : "Open",
                      systemImage: existing == nil ? "square.and.arrow.down" : "arrow.up.forward.app")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .glassButton(prominent: true)
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Save

    private func save() -> Destination {
        switch link.kind {
        case .palette:
            let paletteColors = link.swatches.enumerated().map { index, swatch in
                PaletteColor(color: colors[index], hex: swatch.hex, name: swatch.name, role: swatch.role)
            }
            let palette = PaletteViewModel(name: link.name, paletteColors: paletteColors)
            withAnimation {
                appData.palettes.append(palette)
                appData.addPaletteColorsToLibrary(paletteColors, isGenerated: false)
            }
            ToastManager.shared.show("Palette saved", icon: "checkmark")
            return .palette(palette.id)
        case .color:
            let swatch = link.swatches[0]
            let color = ColorViewModel(
                name: appData.uniqueColorName(preferred: swatch.name, forHex: swatch.hex),
                color: colors[0],
                HEX: swatch.hex,
                usedInPalette: false
            )
            withAnimation { appData.colors.append(color) }
            ToastManager.shared.show("Color saved", icon: "checkmark")
            return .color(color.id)
        }
    }
}

#Preview {
    SharedLinkSheet(
        link: .palette(name: "Kyoto Dusk", swatches: [
            .init(hex: "#F2A65A", name: "Lantern Glow", role: "Accent"),
            .init(hex: "#C8553D", name: "Temple Red", role: "Primary"),
            .init(hex: "#2E2A4F", name: "Indigo Night", role: nil),
        ]),
        onOpen: { _ in }
    )
    .environmentObject(AppData(inMemory: true))
}
