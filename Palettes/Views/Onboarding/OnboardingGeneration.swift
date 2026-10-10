//
//  OnboardingGeneration.swift
//  Palettes
//
//  Builds and saves the onboarding palette. The AI path (iOS 26 with Apple
//  Intelligence available on a real device) reuses `PaletteGenerator`; every
//  other configuration, including the Simulator, builds deterministically
//  with `PaletteBuilder` and never touches FoundationModels.
//

import SwiftUI
import FoundationModels

enum OnboardingPaletteMaker {
    /// Free-tier size from plan 013's even sizes.
    nonisolated static let paletteSize = 4

    struct Made {
        let palette: PaletteViewModel
        /// True only when Apple Intelligence named the palette; drives the
        /// gradient-filled name and the `isGenerated` badge.
        let usedAI: Bool
    }

    @available(iOS 26.0, *)
    private static var modelAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #endif
    }

    /// Whether the AI path will run on this device.
    static var usesAI: Bool {
        if #available(iOS 26.0, *) { return modelAvailable }
        return false
    }

    /// `onColors` receives the palette's colors as they arrive, for the orb.
    /// `revealDelay` paces the deterministic path (0 = all at once).
    static func make(
        anchorHex: String,
        size: Int = paletteSize,
        existingNames: [String],
        revealDelay: Duration = .zero,
        onColors: @escaping @MainActor ([Color]) -> Void
    ) async throws -> Made {
        if #available(iOS 26.0, *), modelAvailable {
            let palette = try await PaletteGenerator.generate(
                baseColors: [.init(hex: anchorHex, name: "")],
                size: size,
                vibe: nil,
                existingNames: existingNames,
                onPartialColors: onColors
            )
            var generated = palette
            generated.isGenerated = true
            return Made(palette: generated, usedAI: true)
        }

        let palette = try deterministicPalette(anchorHex: anchorHex, size: size, existingNames: existingNames)
        let colors = palette.colors
        if revealDelay > .zero {
            for count in 2...max(2, colors.count) {
                try await Task.sleep(for: revealDelay)
                onColors(Array(colors.prefix(count)))
            }
        } else {
            onColors(colors)
        }
        return Made(palette: palette, usedAI: false)
    }

    /// The anchor ships verbatim as the first color; colors, hexes, names and
    /// roles are built together so they stay index-aligned.
    static func deterministicPalette(
        anchorHex: String,
        size: Int = paletteSize,
        existingNames: [String] = [],
        seed: UInt64 = .random(in: .min ... .max)
    ) throws -> PaletteViewModel {
        let built = PaletteBuilder.build(PaletteBuildRequest(
            anchors: [anchorHex],
            size: size,
            scheme: .auto,
            tone: PaletteBrief.neutral.tone,
            hue: nil,
            seed: seed
        ))
        let hexes = built.hexes
        let colors = hexes.compactMap { Color(hex: $0) }
        guard colors.count == hexes.count, colors.count >= 2 else { throw AppError.generationFailed }
        return PaletteViewModel(
            name: PaletteNamer.resolvedName(aiName: nil, hexes: hexes, existingNames: existingNames),
            colors: colors,
            hexCodes: hexes,
            colorNames: ColorNamer.uniqueNames(forHexes: hexes),
            colorRoles: built.roles
        )
    }
}

enum OnboardingPaletteSaver {
    /// Creates the palette through `AppData` and reports completion with the
    /// saved palette's id. Returns that id, or nil when onboarding already
    /// finished (a double tap), so a palette is never saved twice.
    @MainActor
    @discardableResult
    static func save(_ palette: PaletteViewModel, appData: AppData, model: OnboardingModel) -> UUID? {
        guard !model.isFinished else { return nil }
        let trimmed = palette.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = appData.addPalette(
            name: trimmed.isEmpty ? "My First Palette" : trimmed,
            paletteColors: palette.paletteColors,
            isGenerated: palette.isGenerated
        )
        appData.addPaletteColorsToLibrary(palette.paletteColors, isGenerated: palette.isGenerated)
        model.finish(.completed(paletteID: saved.id))
        return saved.id
    }
}

/// A palette name filled with the Apple Intelligence gradient when the AI
/// path produced it, plain text otherwise.
struct OnboardingPaletteName: View {
    let name: String
    let usesGradient: Bool

    var body: some View {
        if #available(iOS 26.0, *), usesGradient {
            TimelineView(.animation) { timeline in
                label.foregroundStyle(GeneratedGradient.style(phase: GeneratedGradient.phase(at: timeline.date)))
            }
        } else {
            label
        }
    }

    private var label: some View {
        Text(name)
            .font(.system(.title, design: .rounded).weight(.bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
