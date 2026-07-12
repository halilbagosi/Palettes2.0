import SwiftUI

struct PaletteView: View {
    
    @State private var isCreatingPalette = false
    @State private var path = NavigationPath()
    @State private var paletteToDelete: PaletteViewModel?
    @State private var paletteToEdit: PaletteViewModel?
    @State private var showDeleteAlert = false
    @EnvironmentObject var appData: AppData

    private let gridColumns = [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)]

    var body: some View {
        NavigationStack(path: $path) {
            if #available(iOS 17.0, *) {
                Group {
                    if appData.palettes.isEmpty {
                        PaletteEmptyView(
                            imageName: "swatchpalette.fill",
                            message: "You currently have no palettes. Create one!",
                            actionTitle: "Create Palette",
                            action: { isCreatingPalette = true }
                        )
                        .transition(.opacity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 20) {
                                ForEach(appData.palettes) { palette in
                                    PaletteCell(
                                        paletteName: palette.name,
                                        colors: palette.colors,
                                        onViewPalette: { path.append(palette) },
                                        onCopy: {
                                            copyToClipboard(palette.hexCodes.joined(separator: ", "), label: "Copied HEX")
                                        }
                                    )
                                    .hoverEffect(.lift)
                                    .contextMenu {
                                        Button {
                                            paletteToEdit = palette
                                        } label: {
                                            Label("Edit Palette", systemImage: "pencil")
                                        }
                                        
                                        Button {
                                            let hexes = palette.hexCodes.joined(separator: ", ")
                                            copyToClipboard(hexes, label: "Copied HEX")
                                        } label: {
                                            Label("Copy as HEX", systemImage: "number")
                                        }
                                        
                                        Button {
                                            let rgbs = palette.colors.map { $0.rgbString }.joined(separator: " | ")
                                            copyToClipboard(rgbs, label: "Copied RGB")
                                        } label: {
                                            Label("Copy as RGB", systemImage: "paintpalette")
                                        }
                                        
                                        Button {
                                            let safePaletteName = palette.name.lowercased().replacingOccurrences(of: " ", with: "-")
                                            var cssLines = ["/* \(palette.name) */", ":root {"]
                                            for (index, colorName) in palette.colorNames.enumerated() {
                                                if index < palette.hexCodes.count {
                                                    let safeColorName = colorName.lowercased().replacingOccurrences(of: " ", with: "-")
                                                    let finalName = safeColorName.isEmpty ? "color-\(index + 1)" : safeColorName
                                                    cssLines.append("  --\(safePaletteName)-\(finalName): \(palette.hexCodes[index]);")
                                                }
                                            }
                                            cssLines.append("}")
                                            copyToClipboard(cssLines.joined(separator: "\n"), label: "Copied CSS")
                                        } label: {
                                            Label("Export as CSS", systemImage: "curlybraces.square")
                                        }
                                        
                                        Button {
                                            let colorVMs = palette.colors.indices.map { index -> ColorViewModel in
                                                let hex = index < palette.hexCodes.count ? palette.hexCodes[index] : ""
                                                let name = index < palette.colorNames.count ? palette.colorNames[index] : "Color \(index + 1)"
                                                return ColorViewModel(name: name, color: palette.colors[index], HEX: hex, usedInPalette: true)
                                            }
                                            if let image = PaletteImageRenderer.renderImage(for: palette, colors: colorVMs) {
                                                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                   let rootVC = windowScene.windows.first?.rootViewController {
                                                    rootVC.present(activityVC, animated: true)
                                                }
                                            }
                                        } label: {
                                            Label("Export as PNG", systemImage: "photo")
                                        }
                                        
                                        Button {
                                            let textToShare = "Check out this palette: \(palette.name)\n" + palette.hexCodes.joined(separator: ", ")
                                            let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
                                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let rootVC = windowScene.windows.first?.rootViewController {
                                                rootVC.present(activityVC, animated: true)
                                            }
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        
                                        Button(role: .destructive) {
                                            paletteToDelete = palette
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete Palette", systemImage: "trash")
                                        }
                                    } preview: {
                                        PaletteCell(
                                            paletteName: palette.name,
                                            colors: palette.colors
                                        )
                                        .frame(width: 360)
                                        .padding(4)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                                .compositingGroup()
                            }
                            .padding()
                        }
                    }
                }
                .navigationTitle("Palettes")
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .toolbar {
                    ToolbarItem(id: "palette-add", placement: .topBarTrailing) {
                        Button {
                            isCreatingPalette = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                        .keyboardShortcut("n", modifiers: .command)
                    }
                }
                .sheet(isPresented: $isCreatingPalette) {
                    NewPaletteView()
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .presentationSizing(.form)
                }
                .alert("Delete Palette", isPresented: $showDeleteAlert, presenting: paletteToDelete) { palette in
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring()) {
                            appData.palettes.removeAll(where: { $0.id == palette.id })
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { palette in
                    Text("Are you sure you want to delete \"\(palette.name)\"?")
                }
                .sheet(item: $paletteToEdit) { palette in
                    PaletteEditSheet(paletteName: palette.name, palette: palette)
                        .environmentObject(appData)
                        .presentationSizing(.form)
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

