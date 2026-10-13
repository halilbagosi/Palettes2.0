//
//  PaletteAddPanel.swift
//  Palettes
//
//  The bottom of the palette editor: the selected way to add colors (Pick ·
//  Scan · Library · Harmony; the editor shows the switch under the palette
//  name). Like the dev branch's sheet, there is no card around it: each
//  source's controls are separate components with their own glass. It is
//  a floor height and no scroll view of its own; the lists inside it
//  scroll within it.
//  Every source hands colors to the editor through `onAdd`, which appends
//  them to the draft.
//

import Combine
import SwiftUI

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
    /// has the keyboard, so the editor scrolls the panel into view.
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
