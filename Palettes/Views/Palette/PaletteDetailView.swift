//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 14.2.26.
//
import SwiftUI
import PhotosUI



// MARK: - New Gallery-Style Palette Detail View

struct PaletteDetailView: View {
    let paletteName: String
    let palette: PaletteViewModel
    @EnvironmentObject var appData: AppData
    @State private var isEditingPalette = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) var dismiss

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == palette.id })
    }

    private var livePalette: PaletteViewModel {
        if let idx = paletteIndex { return appData.palettes[idx] }
        return palette
    }

    private func colorViewModel(at index: Int, from pal: PaletteViewModel) -> ColorViewModel {
        let hex = index < pal.hexCodes.count ? pal.hexCodes[index] : ""
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            return existing
        }
        let name = index < pal.colorNames.count ? pal.colorNames[index] : "Color \(index + 1)"
        return ColorViewModel(name: name, color: pal.colors[index], HEX: hex, usedInPalette: true)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Hero Palette Strip
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(livePalette.colors.indices, id: \.self) { index in
                            Rectangle()
                                .fill(livePalette.colors[index])
                        }
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)

                    Text("\(livePalette.colors.count) color\(livePalette.colors.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // MARK: Color Cards
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)], spacing: 20) {
                    ForEach(Array(livePalette.colors.enumerated()), id: \.offset) { index, _ in
                        let colorVM = colorViewModel(at: index, from: livePalette)
                        ColorCellBig(
                            colorName: colorVM.name,
                            hexCode: colorVM.HEX,
                            color: colorVM.color,
                            isUsedInPalette: true
                        )
                        .contextMenu { colorContextMenu(colorVM) } preview: {
                            ColorMorphCard(
                                colorName: colorVM.name,
                                hexCode: colorVM.HEX,
                                color: colorVM.color,
                                isCompact: false
                            )
                            .frame(width: 360, height: 180)
                            .padding(4)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(livePalette.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    savePaletteAsPNG()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditingPalette = true
                    } label: {
                        Label("Edit Palette", systemImage: "pencil")
                    }

                    Button {
                        toggleFavorite()
                    } label: {
                        Label(livePalette.isFavorite ? "Remove Favorite" : "Favorite",
                              systemImage: livePalette.isFavorite ? "star.slash" : "star")
                    }

                    Button {
                        let hexes = livePalette.hexCodes.joined(separator: ", ")
                        copyToClipboard(hexes, label: "Copied HEX")
                    } label: {
                        Label("Copy as HEX", systemImage: "number")
                    }
                    
                    Button {
                        let rgbs = livePalette.colors.map { $0.rgbString }.joined(separator: " | ")
                        copyToClipboard(rgbs, label: "Copied RGB")
                    } label: {
                        Label("Copy as RGB", systemImage: "paintpalette")
                    }
                    
                    Button {
                        let safePaletteName = livePalette.name.lowercased().replacingOccurrences(of: " ", with: "-")
                        var cssLines = ["/* \(livePalette.name) */", ":root {"]
                        for (index, colorName) in livePalette.colorNames.enumerated() {
                            if index < livePalette.hexCodes.count {
                                let safeColorName = colorName.lowercased().replacingOccurrences(of: " ", with: "-")
                                let finalName = safeColorName.isEmpty ? "color-\(index + 1)" : safeColorName
                                cssLines.append("  --\(safePaletteName)-\(finalName): \(livePalette.hexCodes[index]);")
                            }
                        }
                        cssLines.append("}")
                        copyToClipboard(cssLines.joined(separator: "\n"), label: "Copied CSS")
                    } label: {
                        Label("Export as CSS", systemImage: "curlybraces.square")
                    }

                    Button {
                        let colorVMs = livePalette.colors.indices.map { colorViewModel(at: $0, from: livePalette) }
                        if let image = PaletteImageRenderer.renderImage(for: livePalette, colors: colorVMs) {
                            presentShare(items: [image])
                        }
                    } label: {
                        Label("Export as PNG", systemImage: "photo")
                    }

                    Button {
                        let textToShare = "Check out this palette: \(livePalette.name)\n" + livePalette.hexCodes.joined(separator: ", ")
                        presentShare(items: [textToShare])
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Divider()
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Palette", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditingPalette) {
            PaletteEditSheet(paletteName: livePalette.name, palette: palette)
                .environmentObject(appData)
                .formPresentationSizing()
        }
        .alert("Delete Palette", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                withAnimation(.spring()) {
                    appData.palettes.removeAll(where: { $0.id == palette.id })
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(livePalette.name)\"?")
        }
    }

    // MARK: - Color context menu

    /// Same actions as the Colors tab's card menu, minus edit/delete — those
    /// belong to the library; here the card may be a transient palette color.
    @ViewBuilder
    private func colorContextMenu(_ color: ColorViewModel) -> some View {
        if appData.colors.contains(where: { $0.id == color.id }) {
            Button {
                toggleColorFavorite(color)
            } label: {
                Label(color.isFavorite ? "Remove Favorite" : "Favorite",
                      systemImage: color.isFavorite ? "star.slash" : "star")
            }
        }

        Button {
            copyToClipboard(color.HEX, label: "Copied HEX")
        } label: {
            Label("Copy as HEX", systemImage: "number")
        }

        Button {
            copyToClipboard(color.color.rgbString, label: "Copied RGB")
        } label: {
            Label("Copy as RGB", systemImage: "paintpalette")
        }

        Button {
            let cssName = color.name.lowercased().replacingOccurrences(of: " ", with: "-")
            copyToClipboard("--\(cssName): \(color.HEX);", label: "Copied CSS")
        } label: {
            Label("Export for CSS", systemImage: "curlybraces.square")
        }

        Button {
            presentShare(items: ["Check out this color: \(color.name) (\(color.HEX))"])
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private func toggleColorFavorite(_ color: ColorViewModel) {
        if let idx = appData.colors.firstIndex(where: { $0.id == color.id }) {
            appData.colors[idx].isFavorite.toggle()
        }
    }

    // MARK: - Actions

    private func toggleFavorite() {
        if let idx = paletteIndex {
            appData.palettes[idx].isFavorite.toggle()
        }
    }

    private func presentShare(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.maxX - 50, y: 0, width: 1, height: 1)
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Save as PNG

    @MainActor
    private func savePaletteAsPNG() {
        let colorVMs = livePalette.colors.indices.map { colorViewModel(at: $0, from: livePalette) }
        if let uiImage = PaletteImageRenderer.renderImage(for: livePalette, colors: colorVMs) {
            let activityVC = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                // Find the topmost presented VC to present from
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                activityVC.popoverPresentationController?.sourceView = topVC.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.maxX - 50, y: 0, width: 1, height: 1)
                topVC.present(activityVC, animated: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PaletteDetailView(
            paletteName: "Neon Nights",
            palette: PaletteViewModel(
                name: "Neon Nights",
                colors: [.purple, .pink, .orange, .yellow, .cyan, .blue, .indigo, .black],
                hexCodes: ["#800080", "#FFC0CB", "#FFA500", "#FFFF00", "#00FFFF", "#0000FF", "#4B0082", "#000000"],
                colorNames: ["Purple", "Pink", "Orange", "Yellow", "Cyan", "Blue", "Indigo", "Black"]
            )
        )
    }
}
