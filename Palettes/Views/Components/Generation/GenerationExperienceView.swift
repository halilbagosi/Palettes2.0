//
//  GenerationExperienceView.swift
//  Palettes
//

import SwiftUI

/// Full-screen generation session presented as a cover: the waiting orb morphs
/// into the result stage; Regenerate morphs back.
struct GenerationExperienceView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    let statusText: String
    let generate: () async throws -> PaletteViewModel

    @State private var palette: PaletteViewModel?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea()

            if let palette {
                resultStage(palette)
                    .transition(.blurReplace)
            } else {
                GenerationOrbView(statusText: statusText)
                    .transition(.blurReplace)
            }
        }
        .task {
            if palette == nil { await run() }
        }
    }

    // MARK: - Generation

    private func run() async {
        do {
            let result = try await generate()
            withAnimation(.smooth(duration: 0.7)) { palette = result }
        } catch {
            ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            dismiss()
        }
    }

    private func regenerate() {
        withAnimation(.smooth(duration: 0.5)) { palette = nil }
        Task { await run() }
    }

    private func save() {
        guard let palette else { return }
        appData.palettes.append(palette)
        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        dismiss()
    }

    // MARK: - Result Stage

    private func resultStage(_ palette: PaletteViewModel) -> some View {
        ZStack(alignment: .top) {
            LiquidGradientView(speed: 0.35, intensity: 0.22)
                .blur(radius: 80)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text(palette.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .padding(.top, 72)

                    swatchStrip(palette)
                    colorList(palette)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }

            header
        }
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Spacer()
        }
        .padding(.horizontal)
    }

    private func swatchStrip(_ palette: PaletteViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                Rectangle().fill(palette.colors[i])
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func colorList(_ palette: PaletteViewModel) -> some View {
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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    regenerate()
                } label: {
                    Label("Regenerate", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    GenerationExperienceView(
        statusText: "Warm autumn forest",
        generate: {
            try await Task.sleep(for: .seconds(3))
            return PaletteViewModel(
                name: "Warm Autumn Forest",
                colors: [Color(hex: "A95F4D")!, Color(hex: "D98A6C")!, Color(hex: "F5C79A")!, Color(hex: "E29C88")!],
                hexCodes: ["#A95F4D", "#D98A6C", "#F5C79A", "#E29C88"],
                colorNames: ["Amber", "Maple", "Goldenrod", "Moss"]
            )
        }
    )
    .environmentObject(AppData())
}
