//
//  HarmonyPickerView.swift
//  Palettes
//
//  The add panel's Harmony source. A row of base-color chips (the palette's
//  colors, or the Pick color while the palette is empty) and, for the chosen
//  base, one strip per harmony scheme. Tapping a strip hands its colors to the
//  editor, which appends them. Tap-only, so it may scroll.
//

import SwiftUI

/// Which color the Harmony source builds on.
enum HarmonyBase {
    /// The chosen band if it is still in the palette, else the last color,
    /// else (empty palette) the Pick color. Hexes are "#RRGGBB".
    static func resolve(selectedHex: String?, paletteHexes: [String], pickHex: String) -> String {
        if let selectedHex,
           let match = paletteHexes.first(where: { $0.caseInsensitiveCompare(selectedHex) == .orderedSame }) {
            return match
        }
        return paletteHexes.last ?? pickHex
    }
}

/// How much of a harmony strip is already in the palette.
enum HarmonyRow {
    enum State { case none, partial, all }

    /// `draftHexes` is uppercased ("#RRGGBB"), as `PaletteDraft.hexes` gives it.
    static func state(for hexes: [String], draftHexes: Set<String>) -> State {
        let present = hexes.filter { draftHexes.contains($0.uppercased()) }.count
        if present == 0 { return .none }
        return present == hexes.count ? .all : .partial
    }
}

struct HarmonyPickerView: View {
    let draft: PaletteDraft
    @Binding var selection: UUID?
    /// "#RRGGBB" of the Pick source's color: the base while the palette is empty.
    let pickHex: String
    let onChoose: ([PaletteColor]) -> Void
    /// Takes a fully added harmony's hexes back out of the palette.
    let onRemove: ([String]) -> Void

    /// Spoken names for the strips' hexes; hexes are read until they resolve.
    @State private var names: [String: String] = [:]

    private var selectedHex: String? {
        selection.flatMap { id in draft.colors.first { $0.id == id }?.hex }
    }

    private var base: String {
        HarmonyBase.resolve(selectedHex: selectedHex, paletteHexes: draft.colors.map(\.hex), pickHex: pickHex)
    }

    var body: some View {
        let harmonies = ColorPickerModel.harmonies(for: base)

        VStack(spacing: 8) {
            chips

            FadingScrollView {
                FoldAwareGrid(minimum: 240, maximum: 480, spacing: 8, rowSpacing: 8) {
                    ForEach(harmonies, id: \.scheme) { harmony in
                        row(harmony.scheme.displayName, hexes: harmony.hexes)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: base) { await resolveNames() }
    }

    // MARK: - Base chips

    private var chips: some View {
        HStack(spacing: 10) {
            Text("Based on")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            if draft.colors.isEmpty {
                chip(hex: pickHex, isSelected: true, label: "Pick color", isInteractive: false)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(draft.colors) { entry in
                            Button { selection = entry.id } label: {
                                chip(hex: entry.hex, color: entry.color,
                                     isSelected: entry.hex.caseInsensitiveCompare(base) == .orderedSame,
                                     label: entry.name, isInteractive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .frame(height: 38)
    }

    private func chip(hex: String, color: Color? = nil, isSelected: Bool, label: String, isInteractive: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return shape
            .fill(color ?? Color(hex: hex) ?? .gray)
            .frame(width: 30, height: 30)
            .overlay(shape.strokeBorder(.primary.opacity(0.15), lineWidth: 1))
            // The selected chip gets a white frame just outside its edge.
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white, lineWidth: 2.5)
                        .padding(-3.5)
                        .shadow(color: .black.opacity(0.35), radius: 2)
                }
            }
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(isInteractive ? "Builds the harmonies on this color" : "")
            .accessibilityAddTraits(isInteractive ? (isSelected ? [.isButton, .isSelected] : .isButton) : (isSelected ? .isSelected : []))
    }

    // MARK: - Rows

    private func row(_ title: String, hexes: [String]) -> some View {
        let isAdded = HarmonyRow.state(for: hexes, draftHexes: draft.hexes) == .all
        return Button {
            if isAdded { onRemove(hexes) } else { choose(hexes) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    PaletteStrip(colors: hexes.compactMap { Color(hex: $0) }, height: 30, cornerRadius: 8)
                }
                Image(systemName: isAdded ? "minus.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isAdded ? Color.secondary : Color.accentColor)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .liquidGlass(.regular, in: .rect(cornerRadius: 14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(spokenColors(hexes))")
        .accessibilityValue(isAdded ? "Added" : "")
        .accessibilityHint(isAdded ? "Remove harmony" : "Add harmony")
    }

    private func spokenColors(_ hexes: [String]) -> String {
        hexes.map { names[$0] ?? $0 }.joined(separator: ", ")
    }

    /// Names the current strips once the base settles.
    private func resolveNames() async {
        try? await Task.sleep(for: .milliseconds(150))
        var resolved: [String: String] = [:]
        for harmony in ColorPickerModel.harmonies(for: base) {
            for stripHex in harmony.hexes where resolved[stripHex] == nil {
                if Task.isCancelled { return }
                resolved[stripHex] = ColorNamer.name(forHex: stripHex)
            }
            await Task.yield()
        }
        if !Task.isCancelled { names = resolved }
    }

    /// Adds only the strip's colors the palette doesn't have yet.
    private func choose(_ hexes: [String]) {
        let have = draft.hexes
        let colors = hexes.compactMap { hex -> PaletteColor? in
            guard !have.contains(hex.uppercased()) else { return nil }
            guard let color = Color(hex: hex) else { return nil }
            return PaletteColor(color: color, hex: hex, name: ColorNamer.name(forHex: hex))
        }
        onChoose(colors)
    }
}

#Preview {
    @Previewable @State var selection: UUID?
    HarmonyPickerView(
        draft: PaletteDraft(colors: [
            PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue"),
            PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron"),
        ]),
        selection: $selection,
        pickHex: "#3366CC",
        onChoose: { _ in },
        onRemove: { _ in }
    )
    .frame(height: 260)
    .padding()
    .environmentObject(AppData(inMemory: true))
}
