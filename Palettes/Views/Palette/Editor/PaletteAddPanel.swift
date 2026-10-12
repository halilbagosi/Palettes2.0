//
//  PaletteAddPanel.swift
//  Palettes
//
//  The bottom of the palette editor: the selected way to add colors (Pick ·
//  Scan · Library · Harmony; the editor shows the switch under the palette
//  name). Like the dev branch's sheet, there is no card around it: each
//  source's controls are separate components with their own glass. It is
//  pinned, not scrolled; the lists inside it scroll within it.
//  Every source hands colors to the editor through `onAdd`, which appends
//  them to the draft.
//

import Combine
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
    /// What the editor's header and name field need above the panel, whatever
    /// the container: the strip (72), its caption row with padding (30), the
    /// palette name field with its padding (54) and the panel's own outer
    /// padding (12). Derived from the fixed sizes in `PaletteEditor`.
    static let minimumAbovePanel: CGFloat = 72 + 30 + 54 + 12
    /// The panel never shrinks below this, so the source switch and a picker
    /// (which sizes itself from its measured slot) still render.
    static let floorPanelHeight: CGFloat = 160
    /// Dynamic Type grows the fixed chrome (switches, button, swatch row) but
    /// the screen doesn't grow with it, so the growth is capped.
    static let maxTypeScale: CGFloat = 1.35

    /// The smallest panel for a type size whose body font is `typeScale` times
    /// the default (1 at the default size).
    static func minimum(typeScale: CGFloat) -> CGFloat {
        minPanelHeight * min(max(typeScale, 1), maxTypeScale)
    }

    /// The panel's height in an editor `available` points tall. `minimum` is
    /// what Pick wants; a container too short to give it that and still show
    /// the strip and name field (iPhone landscape, small phones at large type)
    /// shrinks the panel instead, down to `floorPanelHeight`.
    static func panelHeight(available: CGFloat, minimum: CGFloat = minPanelHeight) -> CGFloat {
        let preferred = max(available * panelRatio, minimum)
        let cap = max(available - reservedAbovePanel, minimum)
        let fits = max(available - minimumAbovePanel, floorPanelHeight)
        return min(preferred, cap, fits)
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

// MARK: - Panel

struct PaletteAddPanel: View {
    let draft: PaletteDraft
    @Binding var selection: UUID?
    let source: PaletteAddSource
    /// True while a text field in the panel (Pick's name, Library's search)
    /// has the keyboard, so the editor can make room.
    @Binding var fieldFocused: Bool
    var onAdd: ([PaletteColor]) -> Void
    /// A new photo's colors, to go in place of the previous photo's (`replacing`).
    var onScan: (_ colors: [PaletteColor], _ replacing: Set<UUID>) -> Void
    /// Colors moved in Scan's picker, with their new values.
    var onPicked: ([PaletteColor]) -> Void
    /// Scan's photo was removed; its colors come out of the palette.
    var onRemovePhoto: (PaletteScanSession.Removed, _ undo: @escaping () -> Void) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Kept here, not in the sources, so switching sources doesn't lose them.
    @State private var pickColor = Color(hex: ColorPickerModel.randomStarter()) ?? .blue
    @State private var pickName = ""
    // Reference type in @State: the panel doesn't redraw on every change to it.
    @State private var scan = PaletteScanSession()

    var body: some View {
        // One place for the outgoing and incoming source, so the swap crossfades.
        ZStack {
            Group {
                switch source {
                case .pick:
                    PalettePickSource(
                        color: $pickColor,
                        name: $pickName,
                        excludedHexes: draft.hexes,
                        fieldFocused: $fieldFocused,
                        onAdd: { entry in
                            onAdd([entry])
                            pickColor = Color(hex: ColorPickerModel.nextStarter(excluding: draft.hexes.union([entry.hex.uppercased()]))) ?? .blue
                            pickName = ""
                        }
                    )
                case .scan:
                    PaletteScanSource(session: scan, draft: draft, onPicked: onPicked) { removed in
                        onRemovePhoto(removed) { [scan] in scan.restore(removed) }
                    }
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
            // Nothing draws outside the panel's area, whatever the type size.
            .clipped()
            .transition(.opacity)
        }
        // The content area is a fixed frame, so the swap is a crossfade with no
        // layout movement; Reduce Motion keeps just the (short) fade.
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0), value: source)
        // A photo's colors go into the palette as soon as they are found, even
        // if the user has switched to another source meanwhile.
        .onReceive(scan.$delivery.compactMap { $0 }) { delivery in
            scan.takeDelivery()
            onScan(delivery.colors, delivery.replacing)
        }
    }
}
