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
    /// Enough for Pick: the panel's padding, the source switch, the swatch row,
    /// the picker's mode switch with a usable field (about 90 pt), the Add
    /// button and the gaps. Scaled up with Dynamic Type (see `minimum(typeScale:)`).
    static let minPanelHeight: CGFloat = 350
    /// What the strip and the top of the list need above the panel.
    static let reservedAbovePanel: CGFloat = 240
    /// Dynamic Type grows the fixed chrome (switches, button, swatch row) but
    /// the screen doesn't grow with it, so the growth is capped.
    static let maxTypeScale: CGFloat = 1.35

    /// The smallest panel for a type size whose body font is `typeScale` times
    /// the default (1 at the default size).
    static func minimum(typeScale: CGFloat) -> CGFloat {
        minPanelHeight * min(max(typeScale, 1), maxTypeScale)
    }

    /// The panel's height in an editor `available` points tall.
    static func panelHeight(available: CGFloat, minimum: CGFloat = minPanelHeight) -> CGFloat {
        let preferred = max(available * panelRatio, minimum)
        let cap = max(available - reservedAbovePanel, minimum)
        return min(preferred, cap)
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
    /// True while a text field in the panel (Pick's name, Library's search)
    /// has the keyboard, so the editor can make room.
    @Binding var fieldFocused: Bool
    var onAdd: ([PaletteColor]) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Kept here, not in the sources, so switching sources doesn't lose them.
    @State private var pickColor = Color(hex: ColorPickerModel.randomStarter()) ?? .blue
    @State private var pickName = ""
    // Reference type in @State: the panel doesn't redraw on every pin drag.
    @State private var scan = PhotoPinsSession()

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
                        nameFocused: $fieldFocused,
                        onAdd: { entry in
                            onAdd([entry])
                            pickColor = Color(hex: ColorPickerModel.nextStarter(excluding: draft.hexes.union([entry.hex.uppercased()]))) ?? .blue
                            pickName = ""
                        }
                    )
                case .scan:
                    PaletteScanSource(session: scan, onAdd: onAdd)
                case .library:
                    LibraryPickerView(excludedHexes: draft.hexes, searchFocused: $fieldFocused) { picked in
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
            // Nothing draws outside the card, whatever the type size.
            .clipped()
            .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .snappy, value: source)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(height: height)
        .liquidGlass(.regular, in: .rect(cornerRadius: 24))
        .clipShape(.rect(cornerRadius: 24))
    }
}
