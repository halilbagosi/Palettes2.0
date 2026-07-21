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

@available(iOS 26.0, *)
@Generable
struct GeneratedColor {
    @Guide(description: "A 6-digit RGB hex color code with a leading #, for example #4A90D9")
    var hex: String

    @Guide(description: "A short, evocative name for this color, like 'Electric Blue'")
    var name: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedPalette {
    @Guide(description: "A short, evocative two or three word name for the palette")
    var name: String

    @Guide(description: "The colors that make up the palette")
    var colors: [GeneratedColor]
}

// MARK: - Generator

/// Generates complementary color palettes on-device using Foundation Models.
@available(iOS 26.0, *)
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
        scheme: HarmonyScheme = .auto,
        onPartialColors: (@MainActor ([Color]) -> Void)? = nil
    ) async throws -> PaletteViewModel {
        #if targetEnvironment(simulator)
        // The simulator can't run Apple Intelligence — stream a plan-driven
        // palette so the generation experience can be exercised during development.
        return try await mockGenerate(baseColors: baseColors, size: size, scheme: scheme, onPartialColors: onPartialColors)
        #else
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }

        let seed = UInt64.random(in: .min ... .max)

        // The user's chosen colors are locked: they must appear in the final
        // palette exactly as given. The model only supplies the rest.
        let locked = lockedEntries(from: baseColors)
        let targetCount = max(size, locked.count)
        let remaining = max(0, size - locked.count)

        let trimmedVibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasVibe = !(trimmedVibe?.isEmpty ?? true)

        let instructions: String
        if hasVibe {
            instructions = """
            You are an expert color designer creating harmonious color palettes. \
            Before choosing colors, silently pick a color-harmony strategy that \
            best fits the requested vibe — complementary, split-complementary, \
            analogous, triadic, or monochromatic with a saturated accent — and \
            apply it consistently across every color. For palettes of four or \
            more colors, spread lightness across the set so it includes at \
            least one clearly light color and one clearly dark color. Keep every \
            neighboring pair of colors clearly distinct from each other — never \
            repeat or nearly repeat a hue — and prefer a vivid, saturated accent \
            color over uniformly muted, low-saturation output.
            """
        } else {
            instructions = """
            You are an expert color designer creating harmonious color palettes. \
            Every palette you produce must feel cohesive: complementary hues, \
            balanced lightness, and good contrast between neighboring colors.
            """
        }

        // No-vibe path with base colors present: plan the harmony deterministically
        // and have the model only lightly refine each target. Kept for reuse as the
        // preferred seed for post-validation repairs below.
        let noVibePlan: HarmonyPlan? = (!locked.isEmpty && !hasVibe && remaining > 0)
            ? ColorHarmony.plan(baseHexes: locked.map(\.hex), size: size, scheme: scheme, seed: seed)
            : nil

        var prompt: String
        if locked.isEmpty {
            prompt = "Create a color palette of exactly \(size) colors. Every color must be visually distinct — never repeat or nearly repeat a hex value."
        } else {
            let list = locked.map { "\($0.hex) (\($0.name))" }.joined(separator: ", ")
            if remaining > 0 {
                if let noVibePlan {
                    let targetList = noVibePlan.slots.map(\.hex).joined(separator: ", ")
                    prompt = "These exact colors are already chosen and must stay in the palette unchanged: \(list). Do not modify, replace, or restate them. Generate exactly \(remaining) additional color\(remaining == 1 ? "" : "s") to reach these harmony targets: \(targetList). Refine each target only slightly — keep within about 8 degrees of its hue — and give every color an evocative name. Every added color must be visually distinct and must not repeat any hex value already listed."
                } else {
                    prompt = "These exact colors are already chosen and must stay in the palette unchanged: \(list). Do not modify, replace, or restate them. Generate exactly \(remaining) additional color\(remaining == 1 ? "" : "s") that complement and harmonize with them. Every added color must be visually distinct and must not repeat any hex value already listed."
                }
            } else {
                prompt = "Suggest an evocative name for a palette built from these colors: \(list)."
            }
        }
        if hasVibe, let trimmedVibe {
            prompt += " The palette should capture this vibe: \(trimmedVibe)."
        }
        if scheme != .auto {
            prompt += " Use a \(scheme.displayName) color-harmony scheme."
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

        // Post-validation: drop colors that are too similar to a neighbor, or
        // that leave the palette without enough brightness spread, then
        // repair using a harmony plan so replacements stay in-family rather
        // than drifting to arbitrary golden-ratio hues. Bounded to at most
        // two passes total — the palette is accepted as-is if violations
        // remain after the cap rather than throwing.
        repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            seen: &seenHexes,
            lockedCount: locked.count,
            targetCount: targetCount,
            fallbackPlan: noVibePlan,
            planSeed: seed
        )

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

    // MARK: - Post-validation repair

    /// Removes colors that violate `PaletteValidation`'s distinctness/brightness
    /// rules and refills to `targetCount`, re-checking after each pass.
    /// Bounded to at most two passes total — never an unbounded loop — so a
    /// palette that can't fully satisfy every rule is still returned rather
    /// than looped on forever or thrown away.
    ///
    /// The fill step is unconditional on every pass (not gated on whether
    /// there were violations to remove): the ordinary case where the model
    /// simply returns fewer colors than requested, with zero validation
    /// violations, still needs `fillToTarget` to run or the "always reach
    /// the requested size" guarantee silently breaks. Only the *re-check*
    /// (whether to run a second pass) is conditional on violations
    /// remaining.
    ///
    /// Deliberately unconditional (not nested under `#if targetEnvironment
    /// (simulator)`) so it can be exercised directly in unit tests, which
    /// always run against the simulator and would otherwise never compile
    /// this code path.
    static func repairViolations(
        colors: inout [Color],
        hexCodes: inout [String],
        colorNames: inout [String],
        seen: inout Set<String>,
        lockedCount: Int,
        targetCount: Int,
        fallbackPlan: HarmonyPlan?,
        planSeed: UInt64
    ) {
        var bad = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: lockedCount)
        for _ in 0..<2 {
            // Remove flagged colors, if any — on a pass with no violations
            // this is a no-op, but the fill below still must run.
            for index in bad.sorted(by: >) {
                let removedHex = hexCodes[index]
                colors.remove(at: index)
                hexCodes.remove(at: index)
                colorNames.remove(at: index)
                seen.remove(removedHex)
            }

            // The caller's plan (if one exists) keeps repairs on the
            // originally planned targets; otherwise seed a fresh plan from
            // the surviving colors so repairs stay in the same family. Only
            // computed when there's actually a shortfall to fill.
            let repairPlan: HarmonyPlan? = (colors.count < targetCount)
                ? (fallbackPlan ?? ColorHarmony.plan(baseHexes: hexCodes, size: targetCount, scheme: .auto, seed: planSeed))
                : nil

            // Unconditional: must run even when `bad` was empty, so a
            // shortfall with no violations still gets padded to target.
            fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, seen: &seen, target: targetCount, plan: repairPlan)

            bad = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: lockedCount)
            if bad.isEmpty { break }
        }
    }

    // MARK: - Count guarantee

    /// Ensures the palette reaches `target` colors. Prefers consuming unused
    /// slots from a harmony `plan` (in order, skipping any whose hex fails
    /// the `seen` dedup) so fills/repairs stay in the intended harmony
    /// family; only once the plan is exhausted does it fall back to
    /// synthesizing distinct colors by rotating the hue of existing ones
    /// (golden-ratio spacing) with slight brightness variation, so the final
    /// count always matches the selected size.
    private static func fillToTarget(
        colors: inout [Color],
        hexCodes: inout [String],
        colorNames: inout [String],
        seen: inout Set<String>,
        target: Int,
        plan: HarmonyPlan? = nil
    ) {
        guard target > colors.count else { return }

        if let plan {
            for slot in plan.slots where colors.count < target {
                let hex = slot.hex
                guard seen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
                colors.append(color)
                hexCodes.append(hex)
                colorNames.append(ColorNamer.name(forHex: hex))
            }
        }

        guard target > colors.count else { return }
        let seeds = colors
        // The golden-ratio rotation below seeds new hues off of existing
        // colors; with no plan (or an exhausted one) and a still-empty
        // palette, there's nothing to rotate from, so bail rather than
        // spin the safety counter forever (it only increments inside the
        // `for seed in seeds` loop, which never runs when seeds is empty).
        guard !seeds.isEmpty else { return }
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
        scheme: HarmonyScheme,
        onPartialColors: (@MainActor ([Color]) -> Void)?
    ) async throws -> PaletteViewModel {
        // Locked colors preserved verbatim, then a harmony plan fills the
        // rest — the simulator can't run Apple Intelligence, but this keeps
        // the offline preview structurally consistent with the on-device path.
        let locked = lockedEntries(from: baseColors)
        let targetCount = max(2, max(size, locked.count))

        var colors = locked.map { $0.color }
        var hexCodes = locked.map { $0.hex }
        var colorNames = locked.map { $0.name }
        var seen = Set(hexCodes)

        let seed = UInt64.random(in: .min ... .max)

        // Without a real base color to anchor a plan, synthesize one from the
        // seed so the mock still produces a structured palette; account for
        // the extra (unlisted) base in the requested plan size so slot count
        // still matches what's needed to fill.
        let planBaseHexes: [String]
        let planSize: Int
        if locked.isEmpty {
            let hue = CGFloat(seed % 360) / 360
            let synthetic = UIColor(hue: hue, saturation: 0.55, brightness: 0.6, alpha: 1)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            synthetic.getRed(&r, green: &g, blue: &b, alpha: &a)
            planBaseHexes = [String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))]
            planSize = targetCount + 1
        } else {
            planBaseHexes = locked.map(\.hex)
            planSize = targetCount
        }
        let plan = ColorHarmony.plan(baseHexes: planBaseHexes, size: planSize, scheme: scheme, seed: seed)

        // Guarantee the palette reaches the target size, preferring the
        // harmony plan's slots before falling back to hue rotation.
        fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, seen: &seen, target: targetCount, plan: plan)

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
