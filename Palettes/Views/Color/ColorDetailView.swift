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
    /// iPhone Duo's fold while half open (see `FoldCompat`).
    @State private var fold: Fold?
    /// Ties the color and the sections across the folded and unfolded layouts.
    @Namespace private var foldNamespace

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
        detailContent
            .background(
                LinearGradient(
                    colors: [liveColor.color.opacity(0.8), gradientEnd],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(liveColor.name)
            // Folded, the color needs the height a large title would take.
            .navigationBarTitleDisplayMode(fold == nil ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareColor()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .overflowMenu {
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
                    .formPresentationSizing()
                }
            }
            .sheet(isPresented: $isCreatingPalette) {
                NewPaletteView(preselectedColor: liveColor)
                    .environmentObject(appData)
                    .presentationDetents([.large])
                    .formPresentationSizing()
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

    /// A HEX or channel value, styled like Edit Color's fields. Read-only
    /// here, so a tap copies.
    private func valueField(prefix: String, prefixFont: Font, value: String, spoken: String,
                            copy: @escaping () -> Void) -> some View {
        // HEX reads from the leading edge; a channel's number sits centered
        // beside its letter, as in Edit Color.
        let isHex = prefix == "#"
        return Button(action: copy) {
            HStack(spacing: isHex ? 2 : 3) {
                Text(prefix)
                    .font(prefixFont)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(value)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: isHex ? nil : .infinity)
            }
            .padding(.horizontal, isHex ? 10 : 8)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .rect(cornerRadius: 10))
        .accessibilityLabel("\(spoken) \(value)")
        .accessibilityHint("Copies the value")
    }

    private func copyHex() {
        copyToClipboard(liveColor.HEX, label: "Copied HEX")
    }

    private func copyRGB() {
        let c = liveColor.color.rgbComponents
        copyToClipboard("\(Int(round(c.r))), \(Int(round(c.g))), \(Int(round(c.b)))", label: "Copied RGB")
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
                .liquidGlass(.interactive, in: .capsule)

                if AppleIntelligence.isDeviceSupported {
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
                    .liquidGlass(.interactive, in: .capsule)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
    }

    // MARK: - Layout

    /// The color, then its values and palettes. On iPhone Duo half open, the
    /// color fills the side before the crease (the top, or the left in
    /// landscape) and the values and palettes scroll on the other.
    private var detailContent: some View {
        ZStack {
            if let fold {
                FoldSplit(fold: fold) {
                    colorWindow(fillsHeight: true)
                        .padding()
                } controls: {
                    ScrollView {
                        VStack(spacing: 24) {
                            valuesSection
                            palettesSection
                        }
                        .padding(.vertical)
                        .padding(.vertical, 6)
                    }
                    // Content fades out at the cut edges as it scrolls.
                    .fadingEdges([.top, .bottom], length: 18)
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        colorWindow(fillsHeight: false)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        valuesSection
                        palettesSection
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFoldChange { newFold in
            withAnimation(.smooth(duration: 0.35)) { fold = newFold }
        }
    }

    private func colorWindow(fillsHeight: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(liveColor.color)
            .frame(height: fillsHeight ? nil : 180)
            .frame(maxHeight: fillsHeight ? .infinity : nil)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .swatchEdge(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .matchedGeometryEffect(id: "color", in: foldNamespace)
    }

    /// HEX, R, G and B in one compact row, matching Edit Color.
    private var valuesSection: some View {
        let c = liveColor.color.rgbComponents
        let hex = liveColor.HEX.hasPrefix("#") ? String(liveColor.HEX.dropFirst()) : liveColor.HEX
        let channel = Font.system(size: 12, weight: .semibold)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Values")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .accessibilityAddTraits(.isHeader)

            ValuesRow {
                valueField(prefix: "#", prefixFont: .system(size: 15, weight: .bold, design: .monospaced),
                           value: hex, spoken: "HEX", copy: copyHex)
                valueField(prefix: "R", prefixFont: channel, value: "\(Int(round(c.r)))", spoken: "Red", copy: copyRGB)
                valueField(prefix: "G", prefixFont: channel, value: "\(Int(round(c.g)))", spoken: "Green", copy: copyRGB)
                valueField(prefix: "B", prefixFont: channel, value: "\(Int(round(c.b)))", spoken: "Blue", copy: copyRGB)
            }

            Text("Tap a value to copy it")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .matchedGeometryEffect(id: "values", in: foldNamespace)
    }

    private var palettesSection: some View {
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
                            PaletteCellSearch(
                                paletteName: palette.name,
                                colors: palette.colors,
                                isGenerated: palette.isGenerated
                            )
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                    }
                }
                .padding(.horizontal)
            }
        }
        .matchedGeometryEffect(id: "palettes", in: foldNamespace)
    }

    // MARK: - Actions

    private func shareColor() {
        let textToShare = "Check out this color: \(liveColor.name) (\(liveColor.HEX))"
        ShareSheetPresenter.present(items: [textToShare])
    }

    private func deleteColor() {
        let color = liveColor
        withAnimation(.spring()) {
            for i in appData.palettes.indices {
                if let colorIndex = appData.palettes[i].paletteColors.firstIndex(where: {
                    $0.hex.caseInsensitiveCompare(color.HEX) == .orderedSame
                }) {
                    appData.palettes[i].paletteColors.remove(at: colorIndex)
                }
            }
            appData.palettes.removeAll { $0.paletteColors.isEmpty }
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
