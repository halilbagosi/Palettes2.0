//
//  PaletteGenerator.swift
//  Palettes
//

import Foundation
import SwiftUI
import FoundationModels

// MARK: - Guided generation output types

@Generable
struct GeneratedColor {
    @Guide(description: "A 6-digit RGB hex color code with a leading #, for example #4A90D9")
    var hex: String

    @Guide(description: "A short, evocative name for this color, like 'Electric Blue'")
    var name: String
}

@Generable
struct GeneratedPalette {
    @Guide(description: "A short, evocative two or three word name for the palette")
    var name: String

    @Guide(description: "The colors that make up the palette")
    var colors: [GeneratedColor]
}

// MARK: - Generator

/// Generates complementary color palettes on-device using Foundation Models.
enum PaletteGenerator {

    struct BaseColor {
        let hex: String
        let name: String
    }

    static func generate(
        baseColors: [BaseColor],
        size: Int,
        vibe: String?
    ) async throws -> PaletteViewModel {
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }

        let instructions = """
        You are an expert color designer creating harmonious color palettes. \
        Every palette you produce must feel cohesive: complementary hues, \
        balanced lightness, and good contrast between neighboring colors.
        """

        var prompt = "Create a color palette of exactly \(size) colors."
        if !baseColors.isEmpty {
            let list = baseColors.map { "\($0.hex) (\($0.name))" }.joined(separator: ", ")
            prompt += " Build the palette around these colors and include them in it: \(list)."
            prompt += " Fill the remaining slots with complementary colors that harmonize with them."
        }
        if let vibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines), !vibe.isEmpty {
            prompt += " The palette should capture this vibe: \(vibe)."
        }

        let session = LanguageModelSession(instructions: instructions)

        let generated: GeneratedPalette
        do {
            generated = try await session.respond(to: prompt, generating: GeneratedPalette.self).content
        } catch {
            throw AppError.generationFailed
        }

        var colors: [Color] = []
        var hexCodes: [String] = []
        var colorNames: [String] = []

        for item in generated.colors.prefix(max(size, 2)) {
            var hex = item.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard let color = Color(hex: hex) else { continue }
            colors.append(color)
            hexCodes.append(hex)
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            colorNames.append(trimmed.isEmpty ? ColorNamer.name(forHex: hex) : trimmed)
        }

        guard colors.count >= 2 else { throw AppError.generationFailed }

        let paletteName = generated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PaletteViewModel(
            name: paletteName.isEmpty ? "Generated Palette" : paletteName,
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames
        )
    }
}
