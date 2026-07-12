import SwiftUI

/// Read-only detail page for a single color: preview window, HEX/RGB values
/// and the palettes the color appears in. Mirrors PaletteDetailView's toolbar
/// (share + more menu) and offers create/generate actions when the color is
/// not part of any palette yet.
struct ColorDetailView: View {
    let colorItem: ColorViewModel

    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isEditingColor = false
    @State private var isCreatingPalette = false
    @State private var showDeleteAlert = false

    private var colorIndex: Int? {
        appData.colors.firstIndex(where: { $0.id == colorItem.id })
    }

    /// Always reflect the latest state from AppData (e.g. after editing).
    private var liveColor: ColorViewModel {
        if let idx = colorIndex { return appData.colors[idx] }
        return colorItem
    }

    private var containingPalettes: [PaletteViewModel] {
        appData.palettes.filter { palette in
            palette.hexCodes.contains(where: { $0.caseInsensitiveCompare(liveColor.HEX) == .orderedSame })
        }
    }

    private var gradientEnd: Color {
        let uiColor = UIColor(liveColor.color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if colorScheme == .dark {
            return Color(hue: Double(h), saturation: Double(s), brightness: 0.08)
        } else {
            return Color(hue: Double(h), saturation: Double(s * 0.08), brightness: 0.97)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: Color Window
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(liveColor.color.gradient)
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: liveColor.color.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // MARK: Values
                VStack(alignment: .leading, spacing: 16) {
                    Text("Values")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        valueRow(label: "HEX", value: liveColor.HEX, copyLabel: "Copied HEX")
                        valueRow(label: "RGB", value: liveColor.color.rgbString, copyLabel: "Copied RGB")
                    }
                    .padding(.horizontal)
                }

                // MARK: Palettes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Palettes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    if containingPalettes.isEmpty {
                        emptyPalettesSection
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 14)], spacing: 14) {
                            ForEach(containingPalettes) { palette in
                                NavigationLink(value: palette) {
                                    PaletteCellSearch(paletteName: palette.name, colors: palette.colors)
                                }
                                .buttonStyle(.plain)
                                .hoverEffect(.lift)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [liveColor.color.opacity(0.8), gradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(liveColor.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareColor()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isEditingColor = true
                    } label: {
                        Label("Edit Color", systemImage: "pencil")
                    }

                    Button {
                        copyToClipboard(liveColor.HEX, label: "Copied HEX")
                    } label: {
                        Label("Copy as HEX", systemImage: "number")
                    }

                    Button {
                        copyToClipboard(liveColor.color.rgbString, label: "Copied RGB")
                    } label: {
                        Label("Copy as RGB", systemImage: "paintpalette")
                    }

                    Button {
                        let cssName = liveColor.name.lowercased().replacingOccurrences(of: " ", with: "-")
                        let cssStr = "--\(cssName): \(liveColor.HEX);"
                        copyToClipboard(cssStr, label: "Copied CSS")
                    } label: {
                        Label("Export for CSS", systemImage: "curlybraces.square")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Color", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $isEditingColor) {
            if let idx = colorIndex {
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
        .sheet(isPresented: $isCreatingPalette) {
            NewPaletteView(preselectedColor: liveColor)
                .environmentObject(appData)
                .presentationDetents([.large])
                .presentationSizing(.form)
        }
        .alert("Delete Color", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteColor()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let affected = containingPalettes
            if affected.isEmpty {
                Text("Are you sure you want to delete \"\(liveColor.name)\"?")
            } else {
                Text("Deleting \"\(liveColor.name)\" will also remove it from \(affected.count) palette\(affected.count == 1 ? "" : "s"): \(affected.map(\.name).joined(separator: ", ")).")
            }
        }
    }

    // MARK: - Subviews

    private func valueRow(label: String, value: String, copyLabel: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 50, alignment: .leading)

            Text(value)
                .font(.system(size: 16, design: .monospaced))

            Spacer()

            Button {
                copyToClipboard(value, label: copyLabel)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(label)")
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
    }

    private var emptyPalettesSection: some View {
        VStack(spacing: 16) {
            Text("This color isn't part of any palette yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button {
                    isCreatingPalette = true
                } label: {
                    Label("Create Palette", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button {
                    appData.pendingGenerateColorID = liveColor.id
                    appData.activeTab = .generate
                } label: {
                    Label("Generate Palette", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func shareColor() {
        let textToShare = "Check out this color: \(liveColor.name) (\(liveColor.HEX))"
        let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
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

    private func deleteColor() {
        let color = liveColor
        withAnimation(.spring()) {
            for i in appData.palettes.indices {
                if let colorIndex = appData.palettes[i].hexCodes.firstIndex(where: {
                    $0.caseInsensitiveCompare(color.HEX) == .orderedSame
                }) {
                    appData.palettes[i].colors.remove(at: colorIndex)
                    appData.palettes[i].hexCodes.remove(at: colorIndex)
                    appData.palettes[i].colorNames.remove(at: colorIndex)
                }
            }
            appData.palettes.removeAll { $0.colors.isEmpty }
            appData.colors.removeAll { $0.id == color.id }
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ColorDetailView(
            colorItem: ColorViewModel(
                name: "Maroon",
                color: Color(red: 128/255, green: 0, blue: 0),
                HEX: "#800000",
                usedInPalette: true
            )
        )
        .environmentObject(AppData())
    }
}
