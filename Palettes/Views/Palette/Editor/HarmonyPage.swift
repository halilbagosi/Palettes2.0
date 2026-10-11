//
//  HarmonyPage.swift
//  Palettes
//
//  "From One Color" (the start tile) and "Colors That Go With…" (the + menu).
//  Pick a color at the top; one strip per harmony scheme below follows it
//  live. Tapping a strip hands its colors to the editor, which fills or
//  extends the palette.
//

import SwiftUI

struct HarmonyPage: View {
    /// The color to start from; nil picks a random vivid one (the start tile).
    let base: String?
    let onChoose: ([PaletteColor]) -> Void

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var color: Color

    init(base: String?, onChoose: @escaping ([PaletteColor]) -> Void) {
        self.base = base
        self.onChoose = onChoose
        let hex = base ?? ColorPickerModel.randomStarter()
        _color = State(initialValue: Color(hex: hex) ?? .blue)
    }

    private var hex: String { ColorComposer.hexKey(color) }
    private var title: String { base == nil ? "From One Color" : "Colors That Go With…" }

    /// A gray has no hue to rotate, so its harmonies barely differ.
    private var isNearGray: Bool { color.hsbComponents.s < 0.05 }

    var body: some View {
        let harmonies = ColorPickerModel.harmonies(for: hex)

        VStack(spacing: 0) {
            // Pinned outside the List: the picker's drags would fight a
            // scroll view.
            VStack(spacing: 14) {
                swatch
                ColorPickerPanel(color: $color, onPick: { color = $0 })
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            List {
                Section {
                    ForEach(harmonies, id: \.scheme) { harmony in
                        row(harmony.scheme.displayName, hexes: harmony.hexes)
                    }
                } header: {
                    Text("Harmonies")
                } footer: {
                    if isNearGray {
                        Text("Pick a color with some hue to see more harmonies.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            // Strips follow the drag 1:1.
            .animation(nil, value: hex)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var swatch: some View {
        let ink = color.legibleInk
        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(color)
            .frame(height: 56)
            .overlay(alignment: .leading) {
                Text(hex)
                    .font(.subheadline.monospaced().weight(.medium))
                    .foregroundStyle(ink.opacity(0.8))
                    .padding(.horizontal, 16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Chosen color, \(hex)")
    }

    private func row(_ title: String, hexes: [String]) -> some View {
        Button {
            choose(hexes)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    PaletteStrip(colors: hexes.compactMap { Color(hex: $0) }, height: 40, cornerRadius: 10)
                }
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundStyle(.tint)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(spokenColors(hexes))")
        .accessibilityHint("Adds these colors to the palette")
    }

    /// Naming 25 colors per drag step is wasted work unless someone is
    /// listening.
    private func spokenColors(_ hexes: [String]) -> String {
        guard voiceOverEnabled else { return hexes.joined(separator: ", ") }
        return hexes.map { ColorNamer.name(forHex: $0) }.joined(separator: ", ")
    }

    private func choose(_ hexes: [String]) {
        let colors = hexes.compactMap { hex -> PaletteColor? in
            guard let color = Color(hex: hex) else { return nil }
            return PaletteColor(color: color, hex: hex, name: ColorNamer.name(forHex: hex))
        }
        onChoose(colors)
    }
}

#Preview {
    NavigationStack {
        HarmonyPage(base: "#3366CC", onChoose: { _ in })
    }
    .environmentObject(AppData(inMemory: true))
}
