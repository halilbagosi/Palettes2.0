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
    @Guide(description: "A specific, evocative two or three word title for this exact palette, drawn from its colors or mood — for example 'Harbor Dusk' or 'Terracotta Bloom'. Vary the wording between palettes. Never generic: do not use the words palette, colors, scheme, theme, custom, generated, whisper, horizon, harmony, dream, or serene.")
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
    /// - Parameter existingNames: names already in the user's library, so the
    ///   generated palette's title can be kept distinct from them.
    static func generate(
        baseColors: [BaseColor],
        size: Int,
        vibe: String?,
        scheme: HarmonyScheme = .auto,
        existingNames: [String] = [],
        onPartialColors: (@MainActor ([Color]) -> Void)? = nil
    ) async throws -> PaletteViewModel {
        #if targetEnvironment(simulator)
        // The simulator can't run Apple Intelligence — stream a plan-driven
        // palette so the generation experience can be exercised during development.
        return try await mockGenerate(baseColors: baseColors, size: size, scheme: scheme, existingNames: existingNames, onPartialColors: onPartialColors)
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
            analogous, triadic, or monochromatic tones rooted in the chosen hue — and \
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

        // Plan the harmony deterministically and use those exact colors for
        // both the generation preview and saved palette. This applies with
        // a base and no vibe, or whenever the user selected a concrete mode:
        // without concrete targets, a mode is only a suggestion the model can
        // ignore. The vibe still shapes naming and the palette title.
        let promptPlan: HarmonyPlan? = (!locked.isEmpty && remaining > 0 && (!hasVibe || scheme != .auto))
            ? ColorHarmony.plan(baseHexes: locked.map(\.hex), size: size, scheme: scheme, seed: seed)
            : nil

        // Role source for the locked/base colors. `roleForBases` (the source
        // of `roleForBase`) depends only on the base count, not on scheme or
        // vibe, so it's safe to compute a plan purely for role-tagging
        // purposes even when `promptPlan` above is nil (e.g. a free-form vibe
        // with no explicit scheme). With no base colors at all there's no
        // anchor for "Primary"/"Secondary" to attach to, so roles stay empty
        // in that case — matching the "pure vibe, no bases" rule.
        let rolePlan: HarmonyPlan? = locked.isEmpty
            ? nil
            : (promptPlan ?? ColorHarmony.plan(baseHexes: locked.map(\.hex), size: size, scheme: scheme, seed: seed))

        var prompt: String
        if locked.isEmpty {
            prompt = "Create a color palette of exactly \(size) colors. Every color must be visually distinct — never repeat or nearly repeat a hex value."
        } else {
            let list = locked.map { "\($0.hex) (\($0.name))" }.joined(separator: ", ")
            if remaining > 0 {
                if let promptPlan {
                    let targetList = promptPlan.slots.map(\.hex).joined(separator: ", ")
                    prompt = "These exact colors are already chosen and must stay in the palette unchanged: \(list). Do not modify, replace, or restate them. Return exactly \(remaining) additional colors, in this order and with these exact hex values: \(targetList). Give every added color an evocative name."
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

        // Planned modes already know their final colors. Feed those exact,
        // fully validated colors into the orb one at a time, preserving the
        // original arrival rhythm without ever showing a provisional color
        // that will be replaced at reveal time.
        let plannedOutput: PlannedOutput? = promptPlan.map {
            makePlannedOutput(
                locked: locked,
                baseRoles: rolePlan?.roleForBase.map { $0 ?? "" } ?? [],
                targetCount: targetCount,
                plan: $0,
                planSeed: seed,
                scheme: scheme
            )
        }
        if let onPartialColors, let plannedOutput {
            for index in locked.count..<plannedOutput.colors.count {
                try await Task.sleep(for: .milliseconds(700))
                let previewColors = Array(plannedOutput.colors.prefix(index + 1))
                await MainActor.run { onPartialColors(previewColors) }
            }
        }

        let session = LanguageModelSession(instructions: instructions)

        let generated: GeneratedPalette
        do {
            let stream = session.streamResponse(to: prompt, generating: GeneratedPalette.self)
            for try await snapshot in stream {
                guard let onPartialColors else { continue }
                // Names and title still stream, but a planned mode must never
                // overwrite its correct preview with raw model color guesses.
                guard case nil = plannedOutput else { continue }
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

        var colors: [Color]
        var hexCodes: [String]
        var colorNames: [String]
        var colorRoles: [String]

        if let plannedOutput, let promptPlan {
            colors = plannedOutput.colors
            hexCodes = plannedOutput.hexCodes
            colorNames = plannedOutput.colorNames
            colorRoles = plannedOutput.roles

            // Model-provided color values never replace a validated target,
            // but the name for the corresponding target is still useful.
            var namesByTargetHex: [String: String] = [:]
            for (slot, item) in zip(promptPlan.slots, generated.colors) {
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { namesByTargetHex[slot.hex] = name }
            }
            for index in locked.count..<hexCodes.count {
                if let name = namesByTargetHex[hexCodes[index]] {
                    colorNames[index] = name
                }
            }
        } else {
            // Free-form generation has no predetermined targets, so its
            // accepted model colors remain the source of truth.
            colors = locked.map { $0.color }
            hexCodes = locked.map { $0.hex }
            colorNames = locked.map { $0.name }
            colorRoles = rolePlan?.roleForBase.map { $0 ?? "" } ?? Array(repeating: "", count: locked.count)
            var seenHexes = Set(hexCodes)

            for item in generated.colors {
                guard colors.count < targetCount else { break }
                var hex = item.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if !hex.hasPrefix("#") { hex = "#" + hex }
                guard seenHexes.insert(hex).inserted, let color = Color(hex: hex) else { continue }
                guard isPerceptuallyDistinct(hex, from: hexCodes) else { continue }
                colors.append(color)
                hexCodes.append(hex)
                colorNames.append(item.name.trimmingCharacters(in: .whitespacesAndNewlines))
                colorRoles.append("")
            }

            repairViolations(
                colors: &colors,
                hexCodes: &hexCodes,
                colorNames: &colorNames,
                roles: &colorRoles,
                seen: &seenHexes,
                lockedCount: locked.count,
                targetCount: targetCount,
                fallbackPlan: nil,
                planSeed: seed,
                scheme: scheme
            )
        }

        guard colors.count >= 2 else { throw AppError.generationFailed }

        // Name the FINAL color list (after repair) in one pass, so every
        // name reflects what actually shipped and no two colors in the
        // palette collide on name — locked/user names and the model's own
        // names are honored verbatim when unique; everything else
        // (harmony-slot fills, rotation fallback fills) gets a descriptive
        // name synthesized from its nearest dictionary entry.
        colorNames = ColorNamer.uniqueNames(forHexes: hexCodes, preferred: colorNames)

        // Reflect the final, complete palette in the orb before the reveal.
        if let onPartialColors {
            let finalColors = colors
            await MainActor.run { onPartialColors(finalColors) }
        }

        // The model's title is kept only when it's specific and unused;
        // otherwise a descriptive one is derived from the palette's own colors,
        // so titles stay varied instead of clustering on generic phrases.
        return PaletteViewModel(
            name: PaletteNamer.resolvedName(
                aiName: generated.name,
                hexes: hexCodes,
                existingNames: existingNames
            ),
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames,
            colorRoles: colorRoles
        )
        #endif
    }

    // MARK: - Locked base colors

    private struct LockedColor {
        let color: Color
        let hex: String   // normalized "#RRGGBB"
        let name: String
    }

    /// A plan's fully repaired color output. Keeping this as one small value
    /// lets the orb and returned palette share the *same* color source.
    private struct PlannedOutput {
        let colors: [Color]
        let hexCodes: [String]
        let colorNames: [String]
        let roles: [String]
    }

    /// Resolves a deterministic plan exactly as the final palette will be
    /// resolved: first its explicit slots, then in-family extensions and
    /// validation repair when necessary. Used before model streaming so the
    /// visual preview cannot diverge from the returned palette.
    private static func makePlannedOutput(
        locked: [LockedColor],
        baseRoles: [String],
        targetCount: Int,
        plan: HarmonyPlan,
        planSeed: UInt64,
        scheme: HarmonyScheme
    ) -> PlannedOutput {
        var colors = locked.map(\.color)
        var hexCodes = locked.map(\.hex)
        var colorNames = locked.map(\.name)
        var roles = baseRoles
        var seen = Set(hexCodes)

        fillToTarget(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &roles,
            seen: &seen,
            target: targetCount,
            plan: plan
        )
        repairViolations(
            colors: &colors,
            hexCodes: &hexCodes,
            colorNames: &colorNames,
            roles: &roles,
            seen: &seen,
            lockedCount: locked.count,
            targetCount: targetCount,
            fallbackPlan: plan,
            planSeed: planSeed,
            scheme: scheme
        )

        return PlannedOutput(colors: colors, hexCodes: hexCodes, colorNames: colorNames, roles: roles)
    }

    /// Normalizes and de-duplicates the user's chosen colors, preserving order.
    ///
    /// `name` is left as the user's own text verbatim (or empty if they
    /// didn't provide one) rather than eagerly falling back to
    /// `ColorNamer.name(forHex:)` here — the final `ColorNamer.uniqueNames`
    /// pass over the complete palette (see `generate`/`mockGenerate`) is
    /// what fills in a name for any empty entry, so it can guarantee
    /// uniqueness against every other color that ships, not just pick the
    /// nearest dictionary match in isolation.
    private static func lockedEntries(from baseColors: [BaseColor]) -> [LockedColor] {
        var result: [LockedColor] = []
        var seen = Set<String>()
        for base in baseColors {
            var hex = base.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard seen.insert(hex).inserted, let color = Color(hex: hex) else { continue }
            let name = base.name.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LockedColor(color: color, hex: hex, name: name))
        }
        return result
    }

    // MARK: - Perceptual dedup

    /// Returns whether `hex` is at least `PaletteValidation.minDeltaE` (12)
    /// away, in CIEDE2000, from every color already in `existingHexes`. Used
    /// to gate generated/filled candidates at the point they're added, so a
    /// palette never ships two colors that read as visually the same —
    /// rather than relying solely on after-the-fact repair. Locked/base
    /// colors are never passed through this gate themselves (they always
    /// appear verbatim, even if similar to each other); they only ever
    /// appear on the `existingHexes` side, as a neighbor a new candidate
    /// must stay distinct from.
    private static func isPerceptuallyDistinct(
        _ hex: String,
        from existingHexes: [String],
        minDistance: Double = PaletteValidation.minDeltaE
    ) -> Bool {
        for existing in existingHexes {
            if ColorNamer.perceptualDistance(hex1: hex, hex2: existing) < minDistance {
                return false
            }
        }
        return true
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
        roles: inout [String],
        seen: inout Set<String>,
        lockedCount: Int,
        targetCount: Int,
        fallbackPlan: HarmonyPlan?,
        planSeed: UInt64,
        scheme: HarmonyScheme = .auto
    ) {
        var bad = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: lockedCount)
        for _ in 0..<2 {
            // Remove flagged colors, if any — on a pass with no violations
            // this is a no-op, but the fill below still must run. `roles`
            // must be removed in lockstep with the other three parallel
            // arrays or index alignment breaks for every color after it.
            for index in bad.sorted(by: >) {
                let removedHex = hexCodes[index]
                colors.remove(at: index)
                hexCodes.remove(at: index)
                colorNames.remove(at: index)
                roles.remove(at: index)
                seen.remove(removedHex)
            }

            // The caller's plan (if one exists) keeps repairs on the
            // originally planned targets; otherwise seed a fresh plan from
            // the surviving colors so repairs stay in the same family. The
            // user's chosen `scheme` is carried into that fresh plan — with
            // `.auto` hardcoded here, a repair could re-resolve to a
            // different scheme and pull the palette out of the family the
            // user actually picked. Only computed when there's actually a
            // shortfall to fill.
            let repairPlan: HarmonyPlan? = (colors.count < targetCount)
                ? (fallbackPlan ?? ColorHarmony.plan(baseHexes: hexCodes, size: targetCount, scheme: scheme, seed: planSeed))
                : nil

            // Only inherit slot roles when `repairPlan` is the caller's own
            // deliberate plan (`fallbackPlan`, e.g. the `promptPlan` computed
            // once from the original prompt targets). When `fallbackPlan` is
            // nil, `repairPlan` was just synthesized above from whatever
            // colors happen to be surviving at this point in the repair —
            // an implementation detail, not a deliberate role assignment —
            // so its slots must never leak into `roles`.
            let inheritRoles = fallbackPlan != nil

            // Unconditional: must run even when `bad` was empty, so a
            // shortfall with no violations still gets padded to target.
            fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, roles: &roles, seen: &seen, target: targetCount, plan: repairPlan, inheritRoles: inheritRoles)

            bad = PaletteValidation.violations(hexCodes: hexCodes, lockedCount: lockedCount)
            if bad.isEmpty { break }
        }

        // With no locked/base colors, there is no real anchor for a semantic
        // role to attach to. A shortfall here still routes through an ad-hoc
        // `ColorHarmony.plan` seeded from the surviving (anchor-less) colors
        // themselves, and that plan's slots do carry real roles (Accent when
        // saturated, Background/Text once `reserveNeutrals` fires at size >=
        // 5) — `fillToTarget` appends them verbatim. Suppress them here so
        // "pure vibe, no bases" always yields all-nil roles, matching the
        // guarantee `mockGenerate` already enforces for its own no-base case.
        if lockedCount == 0 {
            roles = Array(repeating: "", count: roles.count)
        }
    }

    // MARK: - Count guarantee

    /// Ensures the palette reaches `target` colors, without ever leaving the
    /// selected harmony family.
    ///
    /// First consumes the `plan`'s own slots (in order, skipping any that
    /// fail the `seen`/perceptual gates); if that leaves a shortfall — which
    /// it routinely does, since a slot that reads the same as a color already
    /// placed is dropped — it keeps drawing *further slots from the same
    /// plan* via `ColorHarmony.extraSlots`, which continues that scheme's own
    /// hue offsets and tone ladder.
    ///
    /// The hue is only ever varied off an existing color as an absolute last
    /// resort, when there is no plan at all to derive a family from — an
    /// earlier version reached for a golden-ratio hue rotation (≈137° per
    /// step) at the first shortfall, which is precisely what put an unrelated
    /// red in the middle of a monochromatic blue palette.
    private static func fillToTarget(
        colors: inout [Color],
        hexCodes: inout [String],
        colorNames: inout [String],
        roles: inout [String],
        seen: inout Set<String>,
        target: Int,
        plan: HarmonyPlan? = nil,
        inheritRoles: Bool = true
    ) {
        guard target > colors.count else { return }

        // Colors filled from a plan slot inherit that slot's role
        // (consumption order == slot order), keeping `roles` aligned with
        // `colors`/`hexCodes`/`colorNames`. `inheritRoles` lets a caller pass
        // a plan purely for its color *values* (e.g. an ad-hoc repair plan
        // with no deliberate role assignment behind it) without leaking its
        // slot roles.
        //
        // A role is never assigned twice within one palette: when the same
        // plan is replayed (e.g. a repair pass restarting from slot 0 after
        // the model under-delivered), the model's refined hex can differ
        // slightly from the slot's hex, so `seen` alone doesn't block the
        // replay — without this check a role like "Accent" could land on two
        // different colors.
        func consume(_ slots: [HarmonySlot], inheritRoles: Bool, minDistance: Double = PaletteValidation.minDeltaE) {
            for slot in slots where colors.count < target {
                let hex = slot.hex
                guard !seen.contains(hex), let color = Color(hex: hex) else { continue }
                // Perceptual gate: a slot that reads as visually the same as
                // a color already in the palette is skipped rather than
                // shipped as a near-duplicate.
                //
                // `seen` is only written once a candidate is actually
                // accepted — it tracks what's IN the palette. Marking
                // rejected candidates as seen would blacklist them for the
                // rest of the fill, including the relaxed-floor retry below,
                // where the very same slot may well be acceptable.
                guard isPerceptuallyDistinct(hex, from: hexCodes, minDistance: minDistance) else { continue }
                seen.insert(hex)
                colors.append(color)
                hexCodes.append(hex)
                // Left empty (no AI/user name for a fill slot) — named
                // descriptively by the final `ColorNamer.uniqueNames` pass
                // over the complete, post-repair palette.
                colorNames.append("")
                let candidateRole = inheritRoles ? (slot.role ?? "") : ""
                if !candidateRole.isEmpty && roles.contains(candidateRole) {
                    roles.append("")
                } else {
                    roles.append(candidateRole)
                }
            }
        }

        if let plan {
            consume(plan.slots, inheritRoles: inheritRoles)

            // Shortfall: continue this plan's ladder. Candidates are drawn
            // generously (the perceptual gate rejects most of them by design)
            // and bounded, so this never spins.
            //
            // The distinctness floor steps down across attempts. A tight
            // family genuinely runs out of room — a single hue can only
            // supply about nine colors that are all a full deltaE 12 apart,
            // so a 12-color monochromatic palette has to choose between
            // shipping short, shipping an off-family color, and shipping
            // neighbouring shades that sit a little closer together. The last
            // is what a monochromatic palette is *supposed* to look like, so
            // the floor relaxes toward 6 — still a visible step, never a
            // repeat — rather than reaching for another hue. Only extension
            // candidates relax; the plan's own slots and the last-resort path
            // below always hold the full floor.
            for floor in [PaletteValidation.minDeltaE, 9, 6] where target > colors.count {
                let shortfall = target - colors.count
                let extras = ColorHarmony.extraSlots(for: plan, count: min(160, max(24, shortfall * 16)))
                // Role-less by construction: an extension slot is a top-up,
                // not part of the deliberate plan.
                consume(extras, inheritRoles: false, minDistance: floor)
            }
        }

        guard target > colors.count else { return }
        // No plan to extend (a hand-built plan carrying no base hexes, or no
        // plan at all). Vary the tone of the colors already present while
        // holding their hue, so even this path stays inside whatever family
        // the palette already has.
        let seeds = colors
        guard !seeds.isEmpty else { return }
        // Hard bound on search attempts: the perceptual gate can reject a
        // candidate as well as an exact-hex repeat, so this must never spin
        // forever — if the bound is hit, fewer than `target` colors are
        // returned rather than a near-duplicate emitted.
        let brightnessSteps: [CGFloat] = [0.22, 0.86, 0.46, 0.96, 0.12, 0.66, 0.34, 0.76]
        let saturationScales: [CGFloat] = [1.0, 0.55, 0.82, 0.3]
        var step = 0
        var safety = 0
        while colors.count < target && safety < target * 48 {
            for seed in seeds where colors.count < target {
                safety += 1
                let ui = UIColor(seed)
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                guard ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { continue }
                let newBright = brightnessSteps[step % brightnessSteps.count]
                let newSat = min(1.0, max(0.04, s * saturationScales[(step / brightnessSteps.count) % saturationScales.count]))
                let ui2 = UIColor(hue: h, saturation: newSat, brightness: newBright, alpha: 1)
                var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, al: CGFloat = 0
                ui2.getRed(&r, green: &g, blue: &bl, alpha: &al)
                let hex = String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(bl * 255)))
                guard !seen.contains(hex), let color = Color(hex: hex) else { continue }
                // Keep searching (next seed/step) until a candidate is
                // perceptually distinct from every color already in the
                // palette — never append a near-duplicate.
                guard isPerceptuallyDistinct(hex, from: hexCodes) else { continue }
                seen.insert(hex)
                colors.append(color)
                hexCodes.append(hex)
                // Named descriptively by the final `ColorNamer.uniqueNames`
                // pass over the complete, post-repair palette.
                colorNames.append("")
                // No slot to inherit a role from — this is a last-resort
                // synthetic fill, so it stays untagged.
                roles.append("")
            }
            step += 1
        }
    }

    #if targetEnvironment(simulator)
    private static func mockGenerate(
        baseColors: [BaseColor],
        size: Int,
        scheme: HarmonyScheme,
        existingNames: [String] = [],
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

        // Locked colors take their role from the plan's `roleForBase` (valid
        // 1:1 against `locked` here since `planBaseHexes == locked.map(\.hex)`
        // whenever `locked` is non-empty). With no locked colors, the plan's
        // base is a synthetic stand-in, not a real user choice, so roles stay
        // empty regardless of what the plan-fill below tags its slots with.
        var colorRoles: [String] = locked.isEmpty ? [] : plan.roleForBase.map { $0 ?? "" }

        // Guarantee the palette reaches the target size, preferring the
        // harmony plan's slots before falling back to hue rotation.
        fillToTarget(colors: &colors, hexCodes: &hexCodes, colorNames: &colorNames, roles: &colorRoles, seen: &seen, target: targetCount, plan: plan)

        if locked.isEmpty {
            // Suppress roles picked up from the synthetic-base plan's slots
            // (e.g. "Accent"/"Background"/"Text") — those slots produced real
            // color *values* to fill with, but with no genuine base color
            // there's no anchor to justify a semantic role tag.
            colorRoles = Array(repeating: "", count: colorRoles.count)
        }

        // The simulator follows the device path: reveal the already-resolved
        // colors one at a time, never temporary placeholders.
        if let onPartialColors {
            for index in locked.count..<colors.count {
                try await Task.sleep(for: .milliseconds(700))
                let previewColors = Array(colors.prefix(index + 1))
                await MainActor.run { onPartialColors(previewColors) }
            }
        }

        // Name the final color list in one pass, same as the on-device path:
        // locked/user names honored verbatim when unique, filled slots get a
        // descriptive name, and nothing collides within the palette.
        colorNames = ColorNamer.uniqueNames(forHexes: hexCodes, preferred: colorNames)

        return PaletteViewModel(
            // No model on the Simulator, so the descriptive namer supplies the
            // title — same behavior a device gets when the model's suggestion
            // is generic or already taken.
            name: PaletteNamer.resolvedName(aiName: nil, hexes: hexCodes, existingNames: existingNames),
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames,
            colorRoles: colorRoles
        )
    }
    #endif
}
