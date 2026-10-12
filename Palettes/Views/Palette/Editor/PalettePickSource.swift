//
//  PalettePickSource.swift
//  Palettes
//
//  The add panel's Pick source.
//

import SwiftUI

/// A compact new-color builder: the swatch with its name and HEX, the picker
/// (Spectrum, Grid or Sliders) and "+ Add to Palette". Scan is the panel's own
/// source, so the picker doesn't offer it here.
struct PalettePickSource: View {
    @Binding var color: Color
    @Binding var name: String
    let excludedHexes: Set<String>
    @Binding var nameFocused: Bool
    var onAdd: (PaletteColor) -> Void

    @EnvironmentObject private var appData: AppData
    @FocusState private var nameField: Bool
    /// The name for the current color, once the color settles.
    @State private var autoName = ""
    /// The height of the slot the picker lives in.
    @State private var slotHeight: CGFloat = 0

    /// The picker's own mode switch (32 pt) and the gap under it come off the
    /// slot; what is left is the field. Never negative, and clipped by the slot.
    private var contentHeight: CGFloat { max(slotHeight - 40, 40) }

    private var hex: String { ColorComposer.hexKey(color) }
    private var isDuplicate: Bool { excludedHexes.contains(hex.uppercased()) }

    var body: some View {
        VStack(spacing: 8) {
            swatchRow

            // The picker gets whatever the panel has left. The slot's size
            // doesn't depend on its content (the picker is an overlay), so
            // measuring it can't feed back into itself.
            Color.clear
                .frame(maxHeight: .infinity)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { slotHeight = $0 }
                .overlay(alignment: .top) {
                    ColorPickerPanel(
                        color: $color,
                        compact: true,
                        allowsScan: false,
                        contentHeight: contentHeight,
                        onPick: { color = $0 }
                    )
                }
                .clipped()

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
        .frame(minHeight: 48)
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
