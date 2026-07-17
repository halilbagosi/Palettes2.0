//
//  PaletteGenerator.swift
//  Palettes
//

import Foundation
import SwiftUI
import UIKit
import FoundationModels
import os

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

    /// Generates a palette, streaming each color to `onPartialColors` as the
    /// model produces it (used to feed the generation orb in real time).
    static func generate(
        baseColors: [BaseColor],
        size: Int,
        vibe: String?,
        onPartialColors: (@MainActor ([Color]) -> Void)? = nil
    ) async throws -> PaletteViewModel {
        #if targetEnvironment(simulator)
        // The simulator can't run Apple Intelligence — stream a fixed palette
        // so the generation experience can be exercised during development.
        return try await mockGenerate(baseColors: baseColors, size: size, onPartialColors: onPartialColors)
        #else
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }

        let instructions = """
        You are an expert color designer creating harmonious color palettes. \
        Every palette you produce must feel cohesive: complementary hues, \
        balanced lightness, and good contrast between neighboring colors.
        """

        // The user's chosen colors are locked: they must appear in the final
        // palette exactly as given. The model only supplies the rest.
        let locked = lockedEntries(from: baseColors)
        let targetCount = max(size, locked.count)
        let remaining = max(0, size - locked.count)

        var prompt: String
        if locked.isEmpty {
            prompt = "Create a color palette of exactly \(size) colors. Every color must be visually distinct — never repeat or nearly repeat a hex value."
        } else {
            let list = locked.map { "\($0.hex) (\($0.name))" }.joined(separator: ", ")
            if remaining > 0 {
                prompt = "These exact colors are already chosen and must stay in the palette unchanged: \(list). Do not modify, replace, or restate them. Generate exactly \(remaining) additional color\(remaining == 1 ? "" : "s") that complement and harmonize with them. Every added color must be visually distinct and must not repeat any hex value already listed."
            } else {
                prompt = "Suggest an evocative name for a palette built from these colors: \(list)."
            }
        }
        if let vibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines), !vibe.isEmpty {
            prompt += " The palette should capture this vibe: \(vibe)."
        }

        let session = LanguageModelSession(instructions: instructions)

        let generated: GeneratedPalette
        do {
            let stream = session.streamResponse(to: prompt, generating: GeneratedPalette.self)
            for try await snapshot in stream {
                guard let onPartialColors else { continue }
                // Locked colors always lead; complementary colors stream in after.
                var shownSeen = Set(locked.map { $0.hex })
                var shown = locked.map { $0.color }
                for item in (snapshot.content.colors ?? []) {
                    guard shown.count < targetCount, var hex = item.hex else { continue }
                    hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if !hex.hasPrefix("#") { hex = "#" + hex }
                    guard shownSeen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
                    shown.append(color)
                }
                let snapshotColors = shown
                await MainActor.run { onPartialColors(snapshotColors) }
            }
            generated = try await stream.collect().content
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Logger(subsystem: "com.halilbagosi.Palettes", category: "generation")
                .error("Palette generation failed: \(String(describing: error), privacy: .public)")
            throw AppError.generationFailed
        }

        // Locked colors first (verbatim), then the model's complementary colors.
        var colors = locked.map { $0.color }
        var hexCodes = locked.map { $0.hex }
        var colorNames = locked.map { $0.name }
        var seenHexes = Set(hexCodes)

        for item in generated.colors {
            guard colors.count < targetCount else { break }
            var hex = item.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard seenHexes.insert(hex).inserted else { continue }
            guard let color = Color(hex: hex) else { continue }
            colors.append(color)
            hexCodes.append(hex)
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            colorNames.append(trimmed.isEmpty ? ColorNamer.name(forHex: hex) : trimmed)
        }

        // The on-device model can return fewer colors than requested; guarantee
        // the palette reaches the selected size with distinct complementary colors.
        fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, seen: &seenHexes, target: targetCount)

        guard colors.count >= 2 else { throw AppError.generationFailed }

        // Reflect the final, complete palette in the orb before the reveal.
        if let onPartialColors {
            let finalColors = colors
            await MainActor.run { onPartialColors(finalColors) }
        }

        let paletteName = generated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PaletteViewModel(
            name: paletteName.isEmpty ? "Generated Palette" : paletteName,
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames
        )
        #endif
    }

    // MARK: - Locked base colors

    private struct LockedColor {
        let color: Color
        let hex: String   // normalized "#RRGGBB"
        let name: String
    }

    /// Normalizes and de-duplicates the user's chosen colors, preserving order.
    private static func lockedEntries(from baseColors: [BaseColor]) -> [LockedColor] {
        var result: [LockedColor] = []
        var seen = Set<String>()
        for base in baseColors {
            var hex = base.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard seen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
            let name = base.name.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LockedColor(color: color, hex: hex, name: name.isEmpty ? ColorNamer.name(forHex: hex) : name))
        }
        return result
    }

    // MARK: - Count guarantee

    /// Ensures the palette reaches `target` colors. When the model returns too
    /// few, synthesizes distinct colors by rotating the hue of existing ones
    /// (golden-ratio spacing) with slight brightness variation, so the final
    /// count always matches the selected size.
    private static func fillToTarget(
        colors: inout [Color],
        hexCodes: inout [String],
        colorNames: inout [String],
        seen: inout Set<String>,
        target: Int
    ) {
        guard target > colors.count, !colors.isEmpty else { return }
        let seeds = colors
        var step = 1
        var safety = 0
        while colors.count < target && safety < target * 24 {
            for seed in seeds where colors.count < target {
                safety += 1
                let ui = UIColor(seed)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { continue }
                var newHue = (h + CGFloat(0.381966 * Double(step))).truncatingRemainder(dividingBy: 1)
                if newHue < 0 { newHue += 1 }
                let newBright = min(0.95, max(0.2, b + CGFloat((step % 3) - 1) * 0.1))
                let newSat = min(1.0, max(0.25, s))
                let ui2 = UIColor(hue: newHue, saturation: newSat, brightness: newBright, alpha: 1)
                var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
                ui2.getRed(&r, green: &g, blue: &bl, alpha: &al)
                let hex = String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(bl * 255)))
                guard seen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
                colors.append(color)
                hexCodes.append(hex)
                colorNames.append(ColorNamer.name(forHex: hex))
            }
            step += 1
        }
    }

    #if targetEnvironment(simulator)
    private static func mockGenerate(
        baseColors: [BaseColor],
        size: Int,
        onPartialColors: (@MainActor ([Color]) -> Void)?
    ) async throws -> PaletteViewModel {
        let pool: [(String, String)] = [
            ("#5B7F8A", "Harbor"), ("#D9A566", "Amber"), ("#8A5B6E", "Mulberry"),
            ("#E8D5B7", "Sand"), ("#3E4E50", "Slate"), ("#C97B63", "Terracotta"),
            ("#7FA98A", "Sage"), ("#4B3B66", "Plum"), ("#E2B8B3", "Rose Dust"),
            ("#2F5D62", "Deep Teal"), ("#F0E2C8", "Cream"), ("#A44A3F", "Rust")
        ]

        // Locked colors preserved verbatim, then complementary colors fill in.
        let locked = lockedEntries(from: baseColors)
        let targetCount = max(2, max(size, locked.count))

        var colors = locked.map { $0.color }
        var hexCodes = locked.map { $0.hex }
        var colorNames = locked.map { $0.name }
        var seen = Set(hexCodes)

        for (hex, name) in pool {
            guard colors.count < targetCount else { break }
            guard seen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
            colors.append(color)
            hexCodes.append(hex)
            colorNames.append(name)
        }

        // Guarantee the palette reaches the target size.
        fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, seen: &seen, target: targetCount)

        // Stream: locked colors appear immediately, then each new one plops in.
        if let onPartialColors {
            var shown = locked.map { $0.color }
            await MainActor.run { onPartialColors(shown) }
            for index in locked.count..<colors.count {
                try await Task.sleep(for: .milliseconds(700))
                shown.append(colors[index])
                let snapshot = shown
                await MainActor.run { onPartialColors(snapshot) }
            }
        }

        return PaletteViewModel(
            name: "Simulator Palette",
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames
        )
    }
    #endif
}
