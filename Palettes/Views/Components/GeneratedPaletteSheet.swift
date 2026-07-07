//
//  GeneratedPaletteSheet.swift
//  Palettes
//

import SwiftUI

/// Preview sheet for an AI-generated palette with Regenerate and Save actions.
struct GeneratedPaletteSheet: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    @State var palette: PaletteViewModel
    let onRegenerate: () async throws -> PaletteViewModel

    @State private var isRegenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    swatchStrip
                    colorList
                }
                .padding()
                .padding(.bottom, 80)
            }
            .navigationTitle(palette.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isRegenerating)
                }
            }
            .safeAreaInset(edge: .bottom) { regenerateButton }
        }
    }

    // MARK: - Swatch Strip

    private var swatchStrip: some View {
        HStack(spacing: 0) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                Rectangle().fill(palette.colors[i])
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(isRegenerating ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }

    // MARK: - Color List

    private var colorList: some View {
        VStack(spacing: 10) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.colors[i].gradient)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(i < palette.colorNames.count ? palette.colorNames[i] : "Color \(i + 1)")
                            .font(.system(size: 15, weight: .semibold))
                        Text(i < palette.hexCodes.count ? palette.hexCodes[i] : "")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .opacity(isRegenerating ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }

    // MARK: - Regenerate

    private var regenerateButton: some View {
        Button {
            regenerate()
        } label: {
            HStack(spacing: 8) {
                if isRegenerating {
                    ProgressView()
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isRegenerating ? "Generating…" : "Regenerate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func save() {
        appData.palettes.append(palette)
        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        dismiss()
    }

    private func regenerate() {
        guard !isRegenerating else { return }
        isRegenerating = true
        Task {
            do {
                let newPalette = try await onRegenerate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    palette = newPalette
                }
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
            isRegenerating = false
        }
    }
}

#Preview {
    GeneratedPaletteSheet(
        palette: PaletteViewModel(
            name: "Midnight Ocean",
            colors: [Color(hex: "1A1A70")!, Color(hex: "007AFF")!, Color(hex: "99FA99")!],
            hexCodes: ["#1A1A70", "#007AFF", "#99FA99"],
            colorNames: ["Midnight", "Electric Blue", "Pastel Mint"]
        ),
        onRegenerate: {
            try await Task.sleep(for: .seconds(1))
            return PaletteViewModel(
                name: "Regenerated",
                colors: [Color(hex: "FF5D00")!, Color(hex: "FF0080")!],
                hexCodes: ["#FF5D00", "#FF0080"],
                colorNames: ["Sunset Orange", "Hot Pink"]
            )
        }
    )
    .environmentObject(AppData())
}
