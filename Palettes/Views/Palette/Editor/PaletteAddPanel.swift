//
//  PaletteAddPanel.swift
//  Palettes
//
//  The pinned panel at the bottom of the palette editor: a segmented switch
//  (Pick · Scan · Library · Harmony) over the selected way to add colors. It
//  is pinned, not scrolled, because its pickers are drag surfaces; the lists
//  inside it (Library, Harmony) are tap-only and scroll within the panel.
//  Every source hands colors to the editor through `onAdd`, which appends
//  them to the draft.
//

import SwiftUI

// MARK: - Layout

/// Sizes for the editor's three bands: the strip (pinned), the list (flexible)
/// and the add panel (pinned). Pure, so it can be tested.
enum PaletteEditorLayout {
    /// The panel's share of the editor's height. Pick needs the most room (a
    /// source switch, a swatch row, the picker with its own mode switch and an
    /// Add button), so the share is a little over half.
    static let panelRatio: CGFloat = 0.55
    static let minPanelHeight: CGFloat = 300
    /// What the strip and the top of the list need above the panel.
    static let reservedAbovePanel: CGFloat = 240

    /// The panel's height in an editor `available` points tall.
    static func panelHeight(available: CGFloat) -> CGFloat {
        let preferred = max(available * panelRatio, minPanelHeight)
        let cap = max(available - reservedAbovePanel, minPanelHeight)
        return min(preferred, cap)
    }

    /// Everything in the Pick source that isn't the picker's own content: the
    /// panel's padding, the source switch, the swatch row, the picker's mode
    /// switch, the Add button and the gaps between them.
    static let pickChrome: CGFloat = 222
    static let minPickerContent: CGFloat = 120

    /// The height left for the picker's field (Spectrum, Grid, Sliders) in a
    /// panel `panelHeight` tall.
    static func pickerContentHeight(panelHeight: CGFloat) -> CGFloat {
        max(panelHeight - pickChrome, minPickerContent)
    }
}

enum PaletteAddSource: String, CaseIterable, Identifiable {
    case pick, scan, library, harmony

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pick: "Pick"
        case .scan: "Scan"
        case .library: "Library"
        case .harmony: "Harmony"
        }
    }

    /// The sources whose content is a drag surface (a swipe down on it must
    /// not be taken for the sheet's dismiss gesture).
    var isDragSurface: Bool { self == .pick || self == .scan }
}

extension View {
    /// A quiet fill for controls that sit inside the panel's glass: glass
    /// doesn't read on glass, so nested controls get a tint instead.
    func panelWell<S: Shape>(in shape: S) -> some View {
        background(Color.primary.opacity(0.07), in: shape)
    }
}

// MARK: - Panel

struct PaletteAddPanel: View {
    let draft: PaletteDraft
    @Binding var selection: UUID?
    @Binding var source: PaletteAddSource
    let height: CGFloat
    /// True while the Pick name field has the keyboard, so the editor can
    /// make room.
    @Binding var colorNameFocused: Bool
    var onAdd: ([PaletteColor]) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Kept here, not in the sources, so switching sources doesn't lose them.
    @State private var pickColor = Color(hex: ColorPickerModel.randomStarter()) ?? .blue
    @State private var pickName = ""
    @State private var scanImage: UIImage?

    var body: some View {
        VStack(spacing: 10) {
            Picker("Add colors from", selection: $source) {
                ForEach(PaletteAddSource.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .sensoryFeedback(.selection, trigger: source)

            Group {
                switch source {
                case .pick:
                    PalettePickSource(
                        color: $pickColor,
                        name: $pickName,
                        excludedHexes: draft.hexes,
                        contentHeight: PaletteEditorLayout.pickerContentHeight(panelHeight: height),
                        nameFocused: $colorNameFocused,
                        onAdd: { entry in
                            onAdd([entry])
                            pickColor = Color(hex: ColorPickerModel.nextStarter(excluding: draft.hexes.union([entry.hex.uppercased()]))) ?? .blue
                            pickName = ""
                        }
                    )
                case .scan:
                    PaletteScanSource(image: $scanImage, onAdd: onAdd)
                case .library:
                    LibraryPickerView(excludedHexes: draft.hexes) { picked in
                        onAdd(picked.map { PaletteColor(color: $0.color, hex: $0.HEX, name: $0.name) })
                    }
                case .harmony:
                    HarmonyPickerView(
                        draft: draft,
                        selection: $selection,
                        pickHex: ColorComposer.hexKey(pickColor),
                        onChoose: onAdd
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .snappy, value: source)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(height: height)
        .liquidGlass(.regular, in: .rect(cornerRadius: 24))
    }
}

// MARK: - Pick

/// A compact new-color builder: the swatch with its name and HEX, the picker
/// (Spectrum, Grid or Sliders) and "+ Add to Palette". Scan is the panel's own
/// source, so the picker doesn't offer it here.
private struct PalettePickSource: View {
    @Binding var color: Color
    @Binding var name: String
    let excludedHexes: Set<String>
    let contentHeight: CGFloat
    @Binding var nameFocused: Bool
    var onAdd: (PaletteColor) -> Void

    @EnvironmentObject private var appData: AppData
    @FocusState private var nameField: Bool
    /// The name for the current color, once the color settles.
    @State private var autoName = ""

    private var hex: String { ColorComposer.hexKey(color) }
    private var isDuplicate: Bool { excludedHexes.contains(hex.uppercased()) }

    var body: some View {
        VStack(spacing: 8) {
            swatchRow

            ColorPickerPanel(
                color: $color,
                compact: true,
                allowsScan: false,
                contentHeight: contentHeight,
                onPick: { color = $0 }
            )

            Button(action: add) {
                Label("Add to Palette", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .glassButton(prominent: true)
            .controlSize(.large)
            .disabled(isDuplicate)
        }
        .task(id: hex) {
            // Names follow the color once it settles, not on every drag frame.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            autoName = suggestedName(forHex: hex)
        }
        .onChange(of: nameField) { _, focused in nameFocused = focused }
        .onDisappear { nameFocused = false }
    }

    private var swatchRow: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.gradient)
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $name, prompt: Text(autoName.isEmpty ? "Name" : autoName))
                    .font(.subheadline.weight(.medium))
                    .submitLabel(.done)
                    .focused($nameField)
                    .onSubmit { nameField = false }
                    .accessibilityLabel("Color name")

                // The HEX and the notice share one line, so a notice never
                // moves the picker.
                ZStack(alignment: .leading) {
                    Text(hex)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .opacity(isDuplicate ? 0 : 1)
                    Label("Already in this palette", systemImage: "info.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .opacity(isDuplicate ? 1 : 0)
                }
                .lineLimit(1)
                .animation(.easeOut(duration: 0.2), value: isDuplicate)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isDuplicate ? "Already in this palette" : "Color preview, \(hex)")
            }
        }
        .frame(height: 48)
    }

    private func add() {
        guard !isDuplicate else { return }
        let typed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = typed.isEmpty ? suggestedName(forHex: hex) : typed
        nameField = false
        onAdd(PaletteColor(color: color, hex: hex, name: resolved))
    }

    /// A saved color's own name first, then ColorNamer, as everywhere else.
    private func suggestedName(forHex hex: String) -> String {
        if let existing = appData.colors.first(where: { $0.HEX.caseInsensitiveCompare(hex) == .orderedSame }) {
            return existing.name
        }
        return ColorNamer.name(forHex: hex)
    }
}
