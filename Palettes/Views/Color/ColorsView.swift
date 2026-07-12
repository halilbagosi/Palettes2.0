//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI

struct ColorsView: View {
    
    @State private var isCreatingColor = false
    @State private var path = NavigationPath()
    @State private var colorForNewPalette: ColorViewModel?
    @State private var colorToDelete: ColorViewModel?
    @State private var colorToEdit: ColorBindingWrapper?
    @State private var showDeleteAlert = false
    @EnvironmentObject var appData: AppData
    
    struct ColorBindingWrapper: Identifiable {
        let id = UUID()
        let color: ColorViewModel
    }

    private let gridColumns = [GridItem(.adaptive(minimum: 340, maximum: 560), spacing: 20)]

    var body: some View {
        NavigationStack(path: $path) {
            if #available(iOS 17.0, *) {
                Group {
                    if appData.colors.isEmpty {
                        PaletteEmptyView(
                            imageName: "circle.grid.cross.fill",
                            message: "You currently have no colors. Create one!",
                            actionTitle: "Create Color",
                            action: { isCreatingColor = true }
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 20) {
                                ForEach(appData.colors) { color in
                                    let matchingPalettes = palettes(for: color)
                                    let isInPalette = !matchingPalettes.isEmpty
                                    
                                    ColorCellBig(
                                        colorName: color.name,
                                        hexCode: color.HEX,
                                        color: color.color,
                                        isUsedInPalette: isInPalette,
                                        onCardTap: {
                                            path.append(color)
                                        },
                                        onViewPalettes: {
                                            path.append(color)
                                        }
                                    )
                                    .hoverEffect(.lift)
                                    .contextMenu {
                                        Button {
                                            colorToEdit = ColorBindingWrapper(color: color)
                                        } label: {
                                            Label("Edit Color", systemImage: "pencil")
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
                                            let cssStr = "--\(cssName): \(color.HEX);"
                                            copyToClipboard(cssStr, label: "Copied CSS")
                                        } label: {
                                            Label("Export for CSS", systemImage: "curlybraces.square")
                                        }
                                        
                                        Button {
                                            let textToShare = "Check out this color: \(color.name) (\(color.HEX))"
                                            let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
                                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                               let rootVC = windowScene.windows.first?.rootViewController {
                                                rootVC.present(activityVC, animated: true)
                                            }
                                        } label: {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        
                                        Button(role: .destructive) {
                                            colorToDelete = color
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete Color", systemImage: "trash")
                                        }
                                    } preview: {
                                        ColorCellBig(
                                            colorName: color.name,
                                            hexCode: color.HEX,
                                            color: color.color,
                                            isUsedInPalette: isInPalette
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
                .navigationTitle("Colors")
                .navigationDestination(for: ColorViewModel.self) { color in
                    ColorDetailView(colorItem: color)
                }
                .navigationDestination(for: PaletteViewModel.self) { palette in
                    PaletteDetailView(paletteName: palette.name, palette: palette)
                }
                .toolbar {
                    ToolbarItem(id: "color-add", placement: .topBarTrailing) {
                        Button {
                            isCreatingColor = true
                        } label: {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    }
                }
                .sheet(isPresented: $isCreatingColor) {
                    NewColorView()
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .presentationSizing(.form)
                }
                .sheet(item: $colorForNewPalette) { color in
                    NewPaletteView(preselectedColor: color)
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .presentationSizing(.form)
                }
                .sheet(item: $colorToEdit) { colorBindingWrapper in
                    if let idx = appData.colors.firstIndex(where: { $0.id == colorBindingWrapper.color.id }) {
                        ColorEditView(
                            colorName: $appData.colors[idx].name,
                            hexCode: $appData.colors[idx].HEX,
                            colorValue: $appData.colors[idx].color
                        )
                        .environmentObject(appData)
                        .presentationDetents([.large])
                        .presentationSizing(.form)
                    }
                }
                .alert("Delete Color", isPresented: $showDeleteAlert, presenting: colorToDelete) { color in
                    Button("Delete", role: .destructive) {
                        withAnimation(.spring()) {
                            // Find all palettes containing this color
                            for i in appData.palettes.indices {
                                if let colorIndex = appData.palettes[i].hexCodes.firstIndex(where: {
                                    $0.caseInsensitiveCompare(color.HEX) == .orderedSame
                                }) {
                                    // Remove the specific color component from this palette
                                    appData.palettes[i].colors.remove(at: colorIndex)
                                    appData.palettes[i].hexCodes.remove(at: colorIndex)
                                    appData.palettes[i].colorNames.remove(at: colorIndex)
                                }
                            }
                            
                            // Remove empty palettes if desired? 
                            // Or leave them empty. (Usually better to remove empty palettes or let user delete manually, standard behavior is leaving them for manual cleanup unless they reach 0)
                            // Let's filter out palettes that now have 0 colors to avoid broken states.
                            appData.palettes.removeAll { $0.colors.isEmpty }
                            
                            // Finally remove the color globally
                            appData.colors.removeAll { $0.id == color.id }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { color in
                    let affected = palettes(for: color)
                    if affected.isEmpty {
                        Text("Are you sure you want to delete \"\(color.name)\"?")
                    } else {
                        Text("Deleting \"\(color.name)\" will also remove it from \(affected.count) palette\(affected.count == 1 ? "" : "s"): \(affected.map(\.name).joined(separator: ", ")).")
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }

    private func palettes(for color: ColorViewModel) -> [PaletteViewModel] {
        appData.palettes.filter { palette in
            palette.hexCodes.contains(where: { $0.caseInsensitiveCompare(color.HEX) == .orderedSame })
        }
    }
}
