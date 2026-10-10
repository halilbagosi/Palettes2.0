//
//  OnboardingGeneration.swift
//  Palettes
//
//  Builds and saves the onboarding palette. With Apple Intelligence (iOS 26
//  on a real, eligible device) onboarding generates around the picked color
//  with `PaletteGenerator`. Without it there is no generation step at all:
//  `fromPhoto` takes the palette straight from the photo's own colors.
//  `deterministicPalette` remains for the debug start at the adjust step.
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
        /// The color the user picked, which the rest was generated around;
        /// nil when the palette was taken from a photo (nothing generated).
        var anchorHex: String? = nil
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

    /// Whether onboarding takes the Apple Intelligence path on this device
    /// (pick a color, generate around it). DEBUG can force it either way.
    static var usesAI: Bool {
        switch OnboardingDebug.aiOverride {
        case .on: return true
        case .off: return false
        case .automatic: return deviceHasAI
        }
    }

    /// For the DEBUG settings footer.
    static var deviceAIStatus: String { deviceHasAI ? "available" : "unavailable" }

    private static var deviceHasAI: Bool {
        if #available(iOS 26.0, *) { return modelAvailable }
        return false
    }

    /// DEBUG forced the AI path on a device that can't run the model: the
    /// palette is built deterministically but treated as generated.
    private static var simulatesAI: Bool { usesAI && !deviceHasAI }

    /// `onColors` receives the palette's colors as they arrive, for the orb.
    /// `revealDelay` paces the deterministic path (0 = all at once).
    static func make(
        anchorHex: String,
        size: Int = paletteSize,
        existingNames: [String],
        revealDelay: Duration = .zero,
        onColors: @escaping @MainActor ([Color]) -> Void
    ) async throws -> Made {
        if usesAI, #available(iOS 26.0, *), modelAvailable {
            let palette = try await PaletteGenerator.generate(
                baseColors: [.init(hex: anchorHex, name: "")],
                size: size,
                vibe: nil,
                existingNames: existingNames,
                onPartialColors: onColors
            )
            var generated = palette
            generated.isGenerated = true
            return Made(palette: generated, usedAI: true, anchorHex: anchorHex)
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
        return Made(palette: palette, usedAI: simulatesAI, anchorHex: anchorHex)
    }

    /// Without Apple Intelligence: the photo's most salient colors become the
    /// palette, revealed one by one like a generation. Nothing is generated,
    /// so the palette and its colors stay untagged.
    static func fromPhoto(
        _ image: UIImage,
        size: Int = paletteSize,
        existingNames: [String],
        revealDelay: Duration = .zero,
        onColors: @escaping @MainActor ([Color]) -> Void
    ) async throws -> Made {
        // The photo is already downscaled and the extractor samples 160 px,
        // so this is quick enough on the main actor (as in ColorInputView).
        let extracted = try ImageColorExtractor.extractColors(from: image, count: size)
        try Task.checkCancellation()
        let palette = try photoPalette(hexes: extracted.map(\.hex), existingNames: existingNames)
        let colors = palette.colors
        if revealDelay > .zero {
            for count in 1...colors.count {
                try await Task.sleep(for: revealDelay)
                onColors(Array(colors.prefix(count)))
            }
        } else {
            onColors(colors)
        }
        return Made(palette: palette, usedAI: false, anchorHex: nil)
    }

    /// Colors, hexes and names built together so they stay index-aligned.
    static func photoPalette(hexes raw: [String], existingNames: [String] = []) throws -> PaletteViewModel {
        let hexes = raw.map { $0.hasPrefix("#") ? $0.uppercased() : "#" + $0.uppercased() }
        let colors = hexes.compactMap { Color(hex: String($0.dropFirst())) }
        guard colors.count == hexes.count, colors.count >= 2 else { throw AppError.colorExtractionFailed }
        return PaletteViewModel(
            name: PaletteNamer.resolvedName(aiName: nil, hexes: hexes, existingNames: existingNames),
            colors: colors,
            hexCodes: hexes,
            colorNames: ColorNamer.uniqueNames(forHexes: hexes)
        )
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
    ///
    /// With `anchorHex` (the palette was generated around a picked color) the
    /// palette is tagged Generated, and so is every color except the picked
    /// one, which the user chose themselves.
    @MainActor
    @discardableResult
    static func save(_ palette: PaletteViewModel, anchorHex: String? = nil,
                     appData: AppData, model: OnboardingModel) -> UUID? {
        guard !model.isFinished else { return nil }
        let generated = anchorHex != nil || palette.isGenerated
        let trimmed = palette.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = appData.addPalette(
            name: trimmed.isEmpty ? "My First Palette" : trimmed,
            paletteColors: palette.paletteColors,
            isGenerated: generated
        )
        let isAnchor: (PaletteColor) -> Bool = { color in
            anchorHex.map { color.hex.caseInsensitiveCompare($0) == .orderedSame } ?? false
        }
        appData.addPaletteColorsToLibrary(palette.paletteColors.filter(isAnchor), isGenerated: false)
        appData.addPaletteColorsToLibrary(palette.paletteColors.filter { !isAnchor($0) }, isGenerated: generated)
        model.finish(.completed(paletteID: saved.id))
        return saved.id
    }
}

/// A palette name filled with the Apple Intelligence gradient when the AI
/// path produced it, plain text otherwise.
struct OnboardingPaletteName: View {
    let name: String
    let usesGradient: Bool
    /// An SF Symbol after the last word, in secondary ink (e.g. an edit cue).
    var trailingSymbol: String? = nil
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if #available(iOS 26.0, *), usesGradient {
            TimelineView(.animation) { timeline in
                label.foregroundStyle(GeneratedGradient.style(phase: GeneratedGradient.phase(at: timeline.date)))
            }
            // The pastel gradient washes out on a light stage: deepen and enrich it
            // there, keeping its hues, and let a faint shadow seat the letters.
            .saturation(colorScheme == .light ? 1.9 : 1)
            .brightness(colorScheme == .light ? -0.38 : 0)
            .shadow(color: .black.opacity(colorScheme == .light ? 0.12 : 0), radius: 1, y: 1)
        } else {
            label
        }
    }

    private var label: some View {
        var text = Text(name)
        if let trailingSymbol {
            text = text + Text("\u{00A0}") + Text(Image(systemName: trailingSymbol))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        return text
            .font(.system(.title, design: .rounded).weight(.bold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}
