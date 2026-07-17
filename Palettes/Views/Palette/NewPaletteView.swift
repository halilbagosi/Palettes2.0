import SwiftUI

struct NewPaletteView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    var preselectedColor: ColorViewModel? = nil

    @State private var paletteName = ""
    @State private var paletteColors: [Color] = []
    @State private var paletteHexCodes: [String] = []
    @State private var paletteColorNames: [String] = []

    @State private var editColorIndex: Int?

    @State private var showDuplicateAlert = false
    @State private var showNameDuplicateAlert = false
    @State private var duplicateOfName = ""

    struct ColorBindingWrapper: Identifiable {
        let id: Int // Index
    }

    private var canCreate: Bool {
        !paletteName.trimmingCharacters(in: .whitespaces).isEmpty && paletteColors.count >= 2
    }

    private var draftHexes: Set<String> {
        Set(paletteHexCodes.map { $0.uppercased() })
    }

    var body: some View {
        NavigationStack {
            scrollContent
                .alert("Palette Already Exists", isPresented: $showDuplicateAlert) {
                    Button("Save Anyway") { performCreate() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A palette with these colors already exists as \"\(duplicateOfName)\".")
                }
                .alert("Name Already Exists", isPresented: $showNameDuplicateAlert) {
                    Button("Save Anyway") { performCreate() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A palette named \"\(duplicateOfName)\" already exists.")
                }
        }
    }

    private var scrollContent: some View {
            ScrollView {
                VStack(spacing: 0) {
                    TextField("Palette Name", text: $paletteName)
                        .font(.system(size: 18, weight: .medium))
                        .padding()
                        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 16)

                    palettePreview

                    if !paletteColors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Added Colors")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            LazyVStack(spacing: 8) {
                                ForEach(paletteColors.indices, id: \.self) { index in
                                    editableColorRow(index: index)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 20)
                    }

                    ColorInputView(
                        sources: [.pick, .scan, .library],
                        initialSource: preselectedColor != nil ? .library : .pick,
                        scanExtraction: .palette(count: 6),
                        excludedHexes: draftHexes,
                        addButtonTitle: "Add Color to Palette",
                        onAdd: { entry in
                            appendToDraft(entry)
                        },
                        onScanPalette: { entries in
                            replaceDraft(with: entries)
                        }
                    )
                    .environmentObject(appData)
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New Palette")
                        .font(.headline)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createPalette() }
                        .glassButton(prominent: true)
                        .fontWeight(.semibold)
                        .disabled(!canCreate)
                }
            }
            .sheet(item: Binding(
                get: {
                    if let idx = editColorIndex, idx < paletteColors.count {
                        return ColorBindingWrapper(id: idx)
                    }
                    return nil
                },
                set: { newValue in
                    if newValue == nil {
                        editColorIndex = nil
                    }
                }
            )) { wrapper in
                ColorEditView(
                    colorName: colorNameBinding(for: wrapper.id),
                    hexCode: hexCodeBinding(for: wrapper.id),
                    colorValue: colorValueBinding(for: wrapper.id)
                )
                .environmentObject(appData)
                .presentationDetents([.large])
            }
            .onAppear {
                if let color = preselectedColor, !draftHexes.contains(color.HEX.uppercased()) {
                    appendToDraft(ColorInputEntry(name: color.name, hex: color.HEX, color: color.color))
                }
            }
    }

    // MARK: - Palette Preview

    var palettePreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            if paletteColors.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "swatchpalette")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Add at least 2 colors to build your palette")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 70)
                .liquidGlass(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 12)
                // Vanish instantly when the first color arrives — a fading
                // glass rim reads as a stray hairline over the strip.
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            } else {
                HStack(spacing: 0) {
                    ForEach(paletteColors.indices, id: \.self) { index in
                        Rectangle()
                            .fill(paletteColors[index])
                            // Overlap neighbors a hairline so antialiasing
                            // can't show a background seam mid-animation.
                            .padding(.horizontal, -0.5)
                    }
                }
                .frame(height: 56)
                // Backdrop inside the clip: the spring bounce briefly leaves
                // gaps between segments, which show this instead of the
                // sheet background.
                .background(paletteColors.last ?? Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .padding(.top, 12)

                Text("\(paletteColors.count) color\(paletteColors.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Draft Color Rows

    @ViewBuilder
    private func editableColorRow(index: Int, swatchSize: CGFloat = 40) -> some View {
        let displayName = index < paletteColorNames.count && !paletteColorNames[index].isEmpty
            ? paletteColorNames[index]
            : "Color \(index + 1)"

        HStack(spacing: 12) {
            Button {
                editColorIndex = index
            } label: {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(paletteColors[index].gradient)
                    .frame(width: swatchSize, height: swatchSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.system(size: 14, weight: .medium))

                if index < paletteHexCodes.count {
                    HStack(spacing: 6) {
                        Text(paletteHexCodes[index])
                            .font(.system(size: 12, weight: .medium, design: .monospaced))

                        Text(paletteColors[index].rgbString)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    removeColor(at: index)
                }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.red.opacity(0.8))
            }
            .accessibilityLabel("Remove color")
        }
        .padding(10)
        .liquidGlass(.regular, in: .rect(cornerRadius: 14))
    }

    private func colorNameBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < paletteColorNames.count ? paletteColorNames[index] : "" },
            set: { newValue in
                if index < paletteColorNames.count {
                    paletteColorNames[index] = newValue
                }
            }
        )
    }

    private func hexCodeBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < paletteHexCodes.count ? paletteHexCodes[index] : "" },
            set: { newValue in
                if index < paletteHexCodes.count {
                    paletteHexCodes[index] = newValue
                }
            }
        )
    }

    private func colorValueBinding(for index: Int) -> Binding<Color> {
        Binding(
            get: { index < paletteColors.count ? paletteColors[index] : .clear },
            set: { newValue in
                if index < paletteColors.count {
                    paletteColors[index] = newValue
                }
            }
        )
    }

    // MARK: - Actions

    private func appendToDraft(_ entry: ColorInputEntry) {
        withAnimation(.spring(response: 0.3)) {
            paletteColors.append(entry.color)
            paletteHexCodes.append(entry.hex)
            paletteColorNames.append(entry.name)
        }
    }

    private func replaceDraft(with entries: [ColorInputEntry]) {
        withAnimation(.spring(response: 0.3)) {
            paletteColors = entries.map { $0.color }
            paletteHexCodes = entries.map { $0.hex }
            paletteColorNames = entries.map { $0.name }
        }
    }

    private func removeColor(at index: Int) {
        guard index < paletteColors.count else { return }
        paletteColors.remove(at: index)
        if index < paletteHexCodes.count { paletteHexCodes.remove(at: index) }
        if index < paletteColorNames.count { paletteColorNames.remove(at: index) }
    }

    private func createPalette() {
        let name = paletteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !paletteColors.isEmpty else { return }

        if let existing = appData.existingPalette(matching: paletteHexCodes) {
            duplicateOfName = existing.name
            showDuplicateAlert = true
            return
        }
        if let existing = appData.existingPalette(named: name) {
            duplicateOfName = existing.name
            showNameDuplicateAlert = true
            return
        }
        performCreate()
    }

    private func performCreate() {
        let name = paletteName.trimmingCharacters(in: .whitespaces)
        let newPalette = PaletteViewModel(
            name: name,
            colors: paletteColors,
            hexCodes: paletteHexCodes,
            colorNames: paletteColorNames
        )
        withAnimation {
            appData.palettes.append(newPalette)

            for i in paletteColors.indices {
                let hex = i < paletteHexCodes.count ? paletteHexCodes[i] : ""
                let colorName = i < paletteColorNames.count ? paletteColorNames[i] : "Untitled"
                guard !hex.isEmpty else { continue }
                let alreadyExists = appData.colors.contains {
                    $0.HEX.caseInsensitiveCompare(hex) == .orderedSame
                }
                if !alreadyExists {
                    let newColor = ColorViewModel(
                        name: colorName,
                        color: paletteColors[i],
                        HEX: hex,
                        usedInPalette: true
                    )
                    appData.colors.append(newColor)
                }
            }
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NewPaletteView()
        .environmentObject(AppData())
}
