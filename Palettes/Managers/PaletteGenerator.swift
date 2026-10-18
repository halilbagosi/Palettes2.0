//
//  PaletteGenerator.swift
//  Palettes
//
//  Generation in three steps:
//   1. Brief — the on-device model reads the vibe into a main color word,
//      a tone and a harmony (`GeneratedBrief`). It never picks color values.
//   2. Build — `PaletteBuilder` makes every color, deterministically.
//   3. Names — the model names each color from a plain description that
//      code writes from the swatch (`ColorVocabulary.describe`). Names are
//      matched back by list number and must pass
//      `ColorVocabulary.isPlausible`; the color dictionary fills any gap.
//  A model failure falls back (heuristic brief, dictionary names), so only
//  cancellation or an unavailable model stops a generation.
//

import Foundation
import SwiftUI
import FoundationModels
import os

// MARK: - Guided generation types

@available(iOS 26.0, *)
@Generable
enum BriefLightness {
    case light, balanced, dark
}

@available(iOS 26.0, *)
@Generable
enum BriefSaturation {
    case muted, balanced, vivid
}

@available(iOS 26.0, *)
@Generable
enum BriefHarmony {
    case analogous, complementary, splitComplementary, triadic, monochromatic
}

@available(iOS 26.0, *)
@Generable
struct GeneratedBrief {
    @Guide(description: "One plain color word for the vibe's main color, such as terracotta, navy, sage, mustard or plum")
    var mainColor: String

    @Guide(description: "How light or dark the palette should feel overall")
    var lightness: BriefLightness

    @Guide(description: "How muted or vivid the palette's colors should be")
    var saturation: BriefSaturation

    @Guide(description: "The color harmony that best suits the vibe")
    var harmony: BriefHarmony

    @Guide(description: "How many colors the palette needs, 4 to 8: fewer for a simple or single-color vibe, more for a rich multi-part one", .range(4...8))
    var suggestedSize: Int
}

@available(iOS 26.0, *)
@Generable
struct GeneratedColorName {
    @Guide(description: "The number of the color in the list")
    var number: Int

    @Guide(description: "The color's name only: one to three words, centered on a noun such as terracotta, sage, cobalt, slate, plum or sand. No mood adjectives like gentle, soft, rich or calm. No commas. Never use the words muted, vivid, moderate, light or dark.")
    var name: String
}

@available(iOS 26.0, *)
@Generable
struct GeneratedNames {
    @Guide(description: "A specific two or three word title for this palette, drawn from its colors or mood, for example 'Harbor Dusk' or 'Terracotta Bloom'. Never generic: do not use the words palette, colors, scheme, theme, custom, generated, whisper, horizon, harmony, dream, or serene.")
    var title: String

    @Guide(description: "One name for every color in the list")
    var colors: [GeneratedColorName]
}

@available(iOS 26.0, *)
extension PaletteBrief {
    /// The model's brief in builder terms. A main color word that neither
    /// the vocabulary nor the dictionary knows keeps the vibe's own reading.
    init(model: GeneratedBrief, vibe: String) {
        let lightness: PaletteTone.Lightness
        switch model.lightness {
        case .light: lightness = .light
        case .balanced: lightness = .balanced
        case .dark: lightness = .dark
        }
        let chroma: PaletteTone.Chroma
        switch model.saturation {
        case .muted: chroma = .muted
        case .balanced: chroma = .balanced
        case .vivid: chroma = .vivid
        }
        let scheme: HarmonyScheme
        switch model.harmony {
        case .analogous: scheme = .analogous
        case .complementary: scheme = .complementary
        case .splitComplementary: scheme = .splitComplementary
        case .triadic: scheme = .triadic
        case .monochromatic: scheme = .monochromatic
        }
        self.init(
            hue: PaletteBrief.hue(forColorWord: model.mainColor) ?? PaletteBrief.heuristic(from: vibe).hue,
            tone: PaletteTone(lightness: lightness, chroma: chroma),
            scheme: scheme,
            suggestedSize: model.suggestedSize
        )
    }
}

// MARK: - Generator

/// Generates palettes on device. The model reads the vibe and names the
/// colors; `PaletteBuilder` makes them.
@available(iOS 26.0, *)
enum PaletteGenerator {

    struct BaseColor {
        let hex: String
        let name: String
    }

    /// Generates a palette, streaming its colors to `onPartialColors` one at
    /// a time for the generation orb. The streamed colors are the final
    /// ones: the builder knows them before the model names them.
    /// - Parameter existingNames: names already in the user's library, so
    ///   the generated palette's title stays distinct from them.
    static func generate(
        baseColors: [BaseColor],
        size: Int?,
        vibe: String?,
        scheme: HarmonyScheme = .auto,
        existingNames: [String] = [],
        onPartialColors: (@MainActor ([Color]) -> Void)? = nil,
        onLateNaming: (@MainActor (PaletteViewModel) -> Void)? = nil,
        onLateNamingTask: (@MainActor (Task<Void, Never>) -> Void)? = nil
    ) async throws -> PaletteViewModel {
        #if !targetEnvironment(simulator)
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }
        #endif

        // The user's chosen colors are locked: they ship verbatim, in order.
        let locked = lockedEntries(from: baseColors)
        let trimmedVibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // 1. Brief.
        let brief = trimmedVibe.isEmpty ? PaletteBrief.neutral : await makeBrief(vibe: trimmedVibe)
        try Task.checkCancellation()
        let targetCount = PaletteBrief.resolvedSize(requested: size, locked: locked.count, suggested: brief.suggestedSize)

        // The user's mode always wins. Auto follows the brief's harmony,
        // unless two or more chosen colors already imply one.
        var resolvedScheme = scheme
        if scheme == .auto, locked.count < 2, let suggested = brief.scheme {
            resolvedScheme = suggested
        }

        // 2. Build.
        let built = PaletteBuilder.build(PaletteBuildRequest(
            anchors: locked.map(\.hex),
            size: targetCount,
            scheme: resolvedScheme,
            tone: brief.tone,
            hue: brief.hue,
            seed: UInt64.random(in: .min ... .max)
        ))
        let hexCodes = built.hexes
        let colors = hexCodes.compactMap { Color(hex: $0) }
        guard colors.count == hexCodes.count, colors.count >= 2 else { throw AppError.generationFailed }

        // 3. Names, requested while the orb shows the colors arriving. The
        //    user's own names are kept; the rest come from the model.
        let userNames = Dictionary(locked.map { ($0.hex, $0.name) }, uniquingKeysWith: { first, _ in first })
        let preferred: [String?] = hexCodes.map { hex in
            guard let name = userNames[hex], !name.isEmpty else { return nil }
            return name
        }
        let unnamed = hexCodes.indices.filter { preferred[$0] == nil }
        let modelVibe = trimmedVibe.isEmpty ? nil : trimmedVibe
        let namingTask = Task { await modelNames(hexes: hexCodes, unnamed: unnamed, vibe: modelVibe) }
        var finished = false
        defer { if !finished { namingTask.cancel() } }

        if let onPartialColors {
            let firstGenerated = min(locked.count, colors.count)
            if firstGenerated == colors.count {
                // Nothing to reveal one by one (e.g. a photo palette): show it whole.
                await MainActor.run { onPartialColors(colors) }
            }
            for index in firstGenerated..<colors.count {
                if GenerationPacing.waitsBeforeRevealing(colorAt: index) {
                    try await Task.sleep(for: GenerationPacing.colorInterval)
                }
                let preview = Array(colors.prefix(index + 1))
                await MainActor.run { onPartialColors(preview) }
            }
        }

        func assemble(_ names: Naming) -> PaletteViewModel {
            var preferred = preferred
            for (index, name) in names.colorNames {
                preferred[index] = name
            }
            return PaletteViewModel(
                // The model's title is kept only when it's specific, names only
                // colors the palette has, and is unused; otherwise a descriptive
                // title is derived from the palette's main color.
                name: PaletteNamer.resolvedName(aiName: names.title, hexes: hexCodes, existingNames: existingNames),
                colors: colors,
                hexCodes: hexCodes,
                colorNames: ColorNamer.uniqueNames(forHexes: hexCodes, preferred: preferred),
                colorRoles: built.roles
            )
        }

        // With a late-naming callback the palette is ready after a short
        // grace period, on fallback names; the model's names follow if they
        // arrive. Without one, wait for the model as before.
        let names: Naming
        if let onLateNaming {
            if let arrived = await NamingRace.firstResult(of: namingTask, within: GenerationPacing.namingGrace) {
                names = arrived
            } else {
                try Task.checkCancellation()
                finished = true
                // The caller owns this task: cancelling it stops the model call
                // and guarantees `onLateNaming` never fires afterwards.
                let lateTask = lateNamingTask(
                    awaiting: namingTask,
                    isUseful: { !$0.colorNames.isEmpty || $0.title != nil },
                    assemble: { assemble($0) },
                    deliver: onLateNaming)
                await MainActor.run { onLateNamingTask?(lateTask) }
                return assemble(Naming(title: nil, colorNames: [:]))
            }
        } else {
            names = await withTaskCancellationHandler { await namingTask.value } onCancel: { namingTask.cancel() }
        }
        try Task.checkCancellation()
        finished = true
        return assemble(names)
    }

    /// Waits for the naming task and hands the assembled palette to
    /// `deliver`, unless cancelled first (cancelling also cancels the naming
    /// task, so the model call stops). Nothing is delivered if `isUseful`
    /// rejects the result.
    static func lateNamingTask<Result: Sendable>(
        awaiting namingTask: Task<Result, Never>,
        isUseful: @escaping @Sendable (Result) -> Bool,
        assemble: @escaping @MainActor (Result) -> PaletteViewModel,
        deliver: @escaping @MainActor (PaletteViewModel) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let late = await withTaskCancellationHandler {
                await namingTask.value
            } onCancel: {
                namingTask.cancel()
            }
            guard !Task.isCancelled, isUseful(late) else { return }
            deliver(assemble(late))
        }
    }

    // MARK: - Locked base colors

    private struct LockedColor {
        let hex: String   // normalized "#RRGGBB"
        let name: String
    }

    /// Normalizes and de-duplicates the user's chosen colors, preserving
    /// order. `name` stays the user's own text (or empty); the final
    /// `ColorNamer.uniqueNames` pass fills in any empty name.
    private static func lockedEntries(from baseColors: [BaseColor]) -> [LockedColor] {
        var result: [LockedColor] = []
        var seen = Set<String>()
        for base in baseColors {
            var hex = base.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard OKLCH(hex: hex) != nil, seen.insert(hex).inserted else { continue }
            let name = base.name.trimmingCharacters(in: .whitespacesAndNewlines)
            result.append(LockedColor(hex: hex, name: name))
        }
        return result
    }

    // MARK: - Model steps

    private static let logger = Logger(subsystem: "com.halilbagosi.Palettes", category: "generation")

    /// Reads the vibe into a brief. On the Simulator, or when the model
    /// fails, the vibe's own words are read instead.
    private static func makeBrief(vibe: String) async -> PaletteBrief {
        #if targetEnvironment(simulator)
        return PaletteBrief.heuristic(from: vibe)
        #else
        do {
            let session = LanguageModelSession(instructions: """
                You are a color designer. Read the mood or theme someone describes and \
                decide what its color palette should be like. Answer only with the fields asked for.
                """)
            let response = try await session.respond(
                to: "Describe the palette for this vibe: \(vibe)",
                generating: GeneratedBrief.self
            )
            return PaletteBrief(model: response.content, vibe: vibe)
        } catch is CancellationError {
            return PaletteBrief.heuristic(from: vibe)
        } catch {
            logFailure(error, step: "brief")
            return PaletteBrief.heuristic(from: vibe)
        }
        #endif
    }

    fileprivate struct Naming {
        var title: String?
        var colorNames: [Int: String]
    }

    /// Asks the model for a title and for names of the colors at `unnamed`.
    /// Every color is described in words, so the model never names from a
    /// hex code; its answers are matched back by number, not position.
    private static func modelNames(hexes: [String], unnamed: [Int], vibe: String?) async -> Naming {
        #if targetEnvironment(simulator)
        return Naming(title: nil, colorNames: [:])
        #else
        let list = hexes.indices
            .map { "\($0 + 1). \(ColorVocabulary.describe(hex: hexes[$0]))" }
            .joined(separator: "\n")
        let theme = vibe.map { " inspired by \"\($0)\"" } ?? ""
        let prompt = """
            Name each color in this palette\(theme), and give the palette a title. \
            Each color is given as lightness, intensity and hue. Answer with the name \
            only: one to three words built on a noun like terracotta, sage, cobalt or \
            sand. Never put a mood adjective (gentle, soft, rich, calm), a comma, or \
            the words muted, vivid, moderate, light or dark in a name. The name must \
            fit: never name a pale color after a loud one, a grey after a hue, or one \
            hue after another.
            \(list)
            """
        do {
            let session = LanguageModelSession(instructions: """
                You name colors for a design app. Use concrete, evocative names drawn from \
                materials, places, food and nature, one to three words each. Never repeat a \
                name, and never use the words color, shade, tone or palette in a name. A color \
                name is a noun like terracotta, sage or cobalt, never an adjective phrase, and \
                never a comma-separated list.
                """)
            let response = try await session.respond(to: prompt, generating: GeneratedNames.self)
            let proposals = response.content.colors.map { (number: $0.number, name: $0.name) }
            return Naming(
                title: response.content.title,
                colorNames: acceptedNames(proposals, hexes: hexes, unnamed: unnamed)
            )
        } catch is CancellationError {
            return Naming(title: nil, colorNames: [:])
        } catch {
            logFailure(error, step: "names")
            return Naming(title: nil, colorNames: [:])
        }
        #endif
    }

    /// The model's names that can ship: matched to colors by list number
    /// (1-based), only for colors that still need a name, and only when the
    /// name fits its swatch and doesn't repeat one already accepted.
    /// Outside the Simulator gate so tests can exercise it.
    static func acceptedNames(_ proposals: [(number: Int, name: String)], hexes: [String], unnamed: [Int]) -> [Int: String] {
        let needed = Set(unnamed)
        var accepted: [Int: String] = [:]
        var used = Set<String>()
        for proposal in proposals {
            let index = proposal.number - 1
            let name = proposal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard needed.contains(index),
                  accepted[index] == nil,
                  ColorVocabulary.isCleanModelName(name),
                  ColorVocabulary.isPlausible(name: name, forHex: hexes[index], strict: true),
                  used.insert(name.lowercased()).inserted else { continue }
            accepted[index] = name
        }
        return accepted
    }

    /// Type name only: an error's description can echo prompt or model
    /// content, which must never reach device logs.
    private static func logFailure(_ error: Error, step: String) {
        logger.error("Palette \(step, privacy: .public) failed: \(String(describing: type(of: error)), privacy: .public)")
    }
}


/// Timing for a generation reveal, kept in one place so the Generate tab and
/// onboarding feel the same and the values are testable.
enum GenerationPacing {
    /// Gap between one color landing and the next.
    static let colorInterval: Duration = .milliseconds(380)
    /// How long "ready" waits for the model's names after the last color.
    static let namingGrace: Duration = .milliseconds(600)

    /// Whether the reveal pauses before showing the color at `index` of the
    /// final palette. Locked colors occupy the first indices and are already
    /// on screen, so the first GENERATED color waits whenever any color is
    /// showing (index > 0). Only index 0, which is generated only when
    /// nothing is locked, lands immediately.
    static func waitsBeforeRevealing(colorAt index: Int) -> Bool { index > 0 }
}

enum NamingRace {
    /// The task's value if it finishes within `timeout`, otherwise nil. The
    /// task itself keeps running either way.
    static func firstResult<T: Sendable>(of task: Task<T, Never>, within timeout: Duration) async -> T? {
        // Unstructured on purpose: a task group would wait for the slow
        // child, and awaiting another task's value ignores cancellation.
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let once = OnceBox<T?>(continuation)
            Task { once.resume(await task.value) }
            Task {
                try? await Task.sleep(for: timeout)
                once.resume(nil)
            }
        }
    }
}

private final class OnceBox<Value: Sendable>: @unchecked Sendable {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Never>?
    init(_ continuation: CheckedContinuation<Value, Never>) { self.continuation = continuation }
    func resume(_ value: Value) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

/// The Generate tab shows its result on fallback names; the model's names
/// follow. They replace only what the user hasn't changed since.
enum GeneratedResultNaming {
    /// - Parameters:
    ///   - name, colors: the result as it is now, possibly edited.
    ///   - shown: the palette the result was first shown with.
    ///   - late: the same palette with the model's names.
    static func merge(name: String, colors: [PaletteColor],
                      shown: PaletteViewModel, late: PaletteViewModel) -> (name: String, colors: [PaletteColor]) {
        let original = shown.paletteColors
        let named = late.paletteColors
        let merged = colors.map { color in
            guard let index = original.firstIndex(where: { $0.id == color.id }),
                  index < named.count,
                  color.name == original[index].name,
                  color.hex == original[index].hex else { return color }
            var renamed = color
            renamed.name = named[index].name
            return renamed
        }
        return (name == shown.name ? late.name : name, merged)
    }
}
