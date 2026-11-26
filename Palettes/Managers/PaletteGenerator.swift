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

    @Guide(description: "A second plain color word when the vibe names two things with different colors, such as 'ocean sunset' (main color blue, second color orange) or 'forest at dusk'. Empty when the vibe is about a single color.")
    var secondColor: String?

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
    @Guide(description: "A specific two or three word title for this palette, drawn from its colors or mood, and from the vibe's own words when there is one (an 'ocean sunset' vibe: 'Ocean Sunset', 'Sunset Tide'), for example 'Harbor Dusk' or 'Terracotta Bloom'. Never generic: do not use the words palette, colors, scheme, theme, custom, generated, whisper, horizon, harmony, dream, or serene.")
    var title: String

    @Guide(description: "One name for every color in the list")
    var colors: [GeneratedColorName]
}

@available(iOS 26.0, *)
@Generable
enum ChangeStep {
    case less, same, more
}

@available(iOS 26.0, *)
@Generable
enum ChangeHarmony {
    case keep, analogous, complementary, splitComplementary, triadic, monochromatic
}

/// A requested change to an existing palette, read relative to it.
@available(iOS 26.0, *)
@Generable
struct GeneratedChange {
    @Guide(description: "more for lighter or paler, less for darker or deeper, same if the request doesn't mention lightness")
    var lightness: ChangeStep

    @Guide(description: "more for more vivid, bold or saturated, less for more muted, dusty or subtle, same if the request doesn't mention it")
    var saturation: ChangeStep

    @Guide(description: "more for warmer (toward red, orange, yellow), less for cooler (toward blue, teal), same if the request doesn't mention temperature")
    var warmth: ChangeStep

    @Guide(description: "One plain color word if the request asks for a different main color, such as teal, navy, sage or plum. Empty if it doesn't.")
    var newMainColor: String

    @Guide(description: "A new color harmony only if the request asks for one, otherwise keep")
    var harmony: ChangeHarmony

    @Guide(description: "more if the request wants more colors, less if fewer, same otherwise")
    var colorCount: ChangeStep
}

@available(iOS 26.0, *)
extension PaletteChange {
    init(model: GeneratedChange, request: String) {
        func delta(_ step: ChangeStep) -> Int {
            switch step {
            case .less: return -1
            case .same: return 0
            case .more: return 1
            }
        }
        // The request's own words settle what the model can't: an exact
        // count, and a step the model missed.
        let words = PaletteChange.heuristic(from: request)
        self.init()
        lightness = delta(model.lightness)
        chroma = delta(model.saturation)
        temperature = delta(model.warmth)
        let color = model.newMainColor.trimmingCharacters(in: .whitespacesAndNewlines)
        mainHue = color.isEmpty ? nil : PaletteBrief.hue(forColorWord: color)
        switch model.harmony {
        case .keep: scheme = nil
        case .analogous: scheme = .analogous
        case .complementary: scheme = .complementary
        case .splitComplementary: scheme = .splitComplementary
        case .triadic: scheme = .triadic
        case .monochromatic: scheme = .monochromatic
        }
        size = words.size
        sizeDelta = delta(model.colorCount)
        if lightness == 0 { lightness = words.lightness }
        if chroma == 0 { chroma = words.chroma }
        if temperature == 0 { temperature = words.temperature }
        if mainHue == nil { mainHue = words.mainHue }
        if scheme == nil { scheme = words.scheme }
        if sizeDelta == 0 { sizeDelta = words.sizeDelta }
    }
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
        let read = PaletteBrief.heuristic(from: vibe)
        let hue = PaletteBrief.reconciledHue(model: PaletteBrief.hue(forColorWord: model.mainColor), vibe: read.hue)
        let second = (model.secondColor ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // The model's second color, else the second hue the vibe's own words
        // carry; either only counts when it sits clear of the main hue.
        // The model's second color never overrides a monochrome vibe.
        let secondary = PaletteBrief.namesSingleColor(ColorVocabulary.tokens(vibe)) ? nil
            : (second.isEmpty ? nil : PaletteBrief.hue(forColorWord: second).flatMap { PaletteBrief.secondHue(after: hue, in: [$0]) })
            ?? read.secondaryHue
        self.init(
            hue: hue,
            secondaryHue: secondary,
            tone: PaletteBrief.reconciledTone(model: PaletteTone(lightness: lightness, chroma: chroma), vibe: read.tone),
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

    /// A change to a palette this generator made: its recipe, and the
    /// user's words for what should change.
    struct Refinement {
        let recipe: GenerationRecipe
        let change: String
    }

    /// Generates a palette, streaming its colors to `onPartialColors` one at
    /// a time for the generation orb. The streamed colors are the final
    /// ones, and they start only once the names are back (or `namingTimeout`
    /// passes), so the result never changes after the orb has filled.
    /// - Parameter existingNames: names already in the user's library, so
    ///   the generated palette's title stays distinct from them.
    /// - Parameter refining: rebuilds that palette with a change applied
    ///   instead of generating a new one; `size` and `scheme` are ignored.
    /// - Parameter onRecipe: receives what the palette was built from, to
    ///   refine it later.
    /// - Parameter namingTimeout: how long the colors wait for the model's
    ///   names before filling on fallback names (see `onLateNaming`).
    /// - Parameter nameVibe: the vibe the palette's title follows, when it
    ///   differs from `vibe` (which also carries described changes).
    /// - Parameter namer: replaces the model's naming step (tests).
    /// - Parameter pinnedStyle: an Auto style the user picked as the mode
    ///   (with `scheme` `.auto`). Every fresh run uses it; no deck draw.
    /// - Parameter deck: hands out the next design style for a fresh run, so
    ///   generating again from the same inputs looks different (tests inject one).
    static func generate(
        baseColors: [BaseColor],
        size: Int?,
        vibe: String?,
        scheme: HarmonyScheme = .auto,
        pinnedStyle: PaletteStyle? = nil,
        existingNames: [String] = [],
        refining: Refinement? = nil,
        nameVibe: String? = nil,
        namingTimeout: Duration = GenerationPacing.namingTimeout,
        namer: Namer? = nil,
        deck: StyleDeckStore = .shared,
        onRecipe: (@MainActor (GenerationRecipe) -> Void)? = nil,
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

        // 1. Brief: read from the vibe, or the last recipe with the change applied.
        var recipe: GenerationRecipe
        if let refining {
            let change = await readChange(refining.change, recipe: refining.recipe)
            recipe = refining.recipe.applying(change, lockedCount: locked.count)
            if change.isEmpty {
                // Not a step from the palette ("more like a beach"): read it
                // as a vibe and take whatever it says over the old brief.
                // A styled palette keeps its style, so only unstyled Auto
                // follows the vibe's harmony (see `merging`). An explicit
                // harmony change ("make it triadic") is a step, handled in `applying`.
                recipe = recipe.merging(await makeBrief(vibe: refining.change))
            }
            // A change must change something.
            if recipe == refining.recipe { recipe.seed = UInt64.random(in: .min ... .max) }
        } else {
            let brief = trimmedVibe.isEmpty ? PaletteBrief.neutral : await makeBrief(vibe: trimmedVibe)
            // A picked style is used as is. Otherwise each fresh run from the
            // same colors, mode and vibe takes the next style in the mode's
            // deck: Auto walks the styles best-suited to the colors first,
            // interface modes shuffle.
            assert(pinnedStyle == nil || (pinnedStyle?.treatment != nil && scheme == .auto), "a pinned style is an Auto style")
            let deckKey = StyleDeckKey(anchors: locked.map(\.hex), scheme: scheme, vibe: trimmedVibe)
            let style: PaletteStyle?
            if let pinnedStyle {
                style = pinnedStyle
            } else if scheme == .auto {
                let auto = StyleDeck.autoCandidates(anchors: locked.map(\.hex), brief: brief)
                style = deck.next(for: deckKey, candidates: auto.styles, first: auto.first, ordered: auto.ordered)
            } else {
                style = deck.next(for: deckKey, candidates: PaletteStyle.deck(for: scheme))
            }
            // The user's mode always wins. Unstyled Auto follows the brief's
            // harmony, unless two or more chosen colors already imply one;
            // styled Auto leaves the harmony to its style.
            // A vibe that names two colors is not one-hue, whatever the model's harmony.
            var resolvedScheme = scheme
            if style == nil, scheme == .auto, locked.count < 2, let suggested = brief.scheme,
               !(suggested == .monochromatic && brief.secondaryHue != nil) {
                resolvedScheme = suggested
            }
            recipe = GenerationRecipe(
                brief: brief,
                size: PaletteBrief.resolvedSize(requested: size, locked: locked.count, suggested: brief.suggestedSize, interface: resolvedScheme.isUIMode),
                scheme: resolvedScheme,
                seed: UInt64.random(in: .min ... .max),
                style: style
            )
        }
        try Task.checkCancellation()

        // 2. Build.
        let built = PaletteBuilder.build(PaletteBuildRequest(
            anchors: locked.map(\.hex),
            size: recipe.size,
            scheme: recipe.scheme,
            tone: recipe.brief.tone,
            hue: recipe.brief.hue,
            secondaryHue: recipe.brief.secondaryHue,
            seed: recipe.seed,
            style: recipe.style
        ))
        recipe.builtHue = built.mainHue
        if let onRecipe {
            let finished = recipe
            await MainActor.run { onRecipe(finished) }
        }
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
        let titleVibe = nameVibe ?? modelVibe
        let arrived = ArrivedNames()
        let namingTask = Task { @MainActor in
            let result: Naming
            if let namer { result = await namer(hexCodes, unnamed, modelVibe) }
            else { result = await modelNames(hexes: hexCodes, unnamed: unnamed, vibe: modelVibe) }
            arrived.set(result)
            return result
        }
        var finished = false
        defer { if !finished { namingTask.cancel() } }

        func assemble(_ names: Naming) -> PaletteViewModel {
            var preferred = preferred
            for (index, name) in names.colorNames {
                preferred[index] = name
            }
            return PaletteViewModel(
                // The model's title is kept only when it's specific, names only
                // colors the palette has, and is unused; otherwise a descriptive
                // title is derived from the palette's main color.
                name: PaletteNamer.resolvedName(aiName: names.title, hexes: hexCodes, existingNames: existingNames, vibe: titleVibe),
                colors: colors,
                hexCodes: hexCodes,
                colorNames: ColorNamer.uniqueNames(forHexes: hexCodes, preferred: preferred),
                colorRoles: built.roles
            )
        }

        // The orb stays in its working state until the names are back: the
        // result then ships exactly what the orb shows, and nothing is
        // renamed afterwards. With a late-naming callback the wait is
        // bounded; at the timeout the colors fill on fallback names and the
        // model's names follow if they arrive.
        var names: Naming?
        if onLateNaming != nil {
            names = await withTaskCancellationHandler {
                await NamingRace.firstResult(of: namingTask, within: namingTimeout)
            } onCancel: { namingTask.cancel() }
        } else {
            names = await withTaskCancellationHandler { await namingTask.value } onCancel: { namingTask.cancel() }
        }
        try Task.checkCancellation()

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
        try Task.checkCancellation()

        // Names that arrived after the timeout but before the fill ended
        // ship with the result, so nothing is delivered late.
        if let final = names ?? arrived.value {
            finished = true
            return assemble(final)
        }
        // Timed out: the caller owns the late task. Cancelling it stops the
        // model call and guarantees `onLateNaming` never fires afterwards.
        finished = true
        if let onLateNaming {
            let lateTask = lateNamingTask(
                awaiting: namingTask,
                isUseful: { !$0.colorNames.isEmpty || $0.title != nil },
                assemble: { assemble($0) },
                deliver: onLateNaming)
            await MainActor.run { onLateNamingTask?(lateTask) }
        }
        return assemble(Naming(title: nil, colorNames: [:]))
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
                decide what its color palette should be like. When the vibe names two things with \
                different colors, such as an ocean sunset, give the color of each. \
                Answer only with the fields asked for.
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

    /// Reads a requested change relative to the palette's recipe. On the
    /// Simulator, or when the model fails, the change's own words are read.
    private static func readChange(_ request: String, recipe: GenerationRecipe) async -> PaletteChange {
        let trimmed = request.trimmingCharacters(in: .whitespacesAndNewlines)
        #if targetEnvironment(simulator)
        return PaletteChange.heuristic(from: trimmed)
        #else
        let tone = recipe.brief.tone
        let current = "\(tone.lightness.rawValue) lightness, \(tone.chroma.rawValue) saturation, \(recipe.size) colors"
        do {
            let session = LanguageModelSession(instructions: """
                You are a color designer adjusting an existing palette. Read what someone \
                wants changed and answer only with the fields asked for. Mark a field as \
                unchanged unless the request asks for it.
                """)
            let response = try await session.respond(
                to: "The palette is \(current). Change requested: \(trimmed)",
                generating: GeneratedChange.self
            )
            return PaletteChange(model: response.content, request: trimmed)
        } catch is CancellationError {
            return PaletteChange.heuristic(from: trimmed)
        } catch {
            logFailure(error, step: "change")
            return PaletteChange.heuristic(from: trimmed)
        }
        #endif
    }

    struct Naming: Sendable {
        var title: String?
        var colorNames: [Int: String]
    }

    /// Names a palette's colors: their hexes, the indices still unnamed,
    /// and the vibe. The model's naming step, or a stand-in for it.
    typealias Namer = @MainActor (_ hexes: [String], _ unnamed: [Int], _ vibe: String?) async -> Naming

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
    /// How long the orb waits, empty, for the model's names before it fills
    /// on fallback names and lets the names follow. A model that answers
    /// takes a second or two.
    static let namingTimeout: Duration = .seconds(5)

    /// Whether the reveal pauses before showing the color at `index` of the
    /// final palette. Locked colors occupy the first indices and are already
    /// on screen, so the first GENERATED color waits whenever any color is
    /// showing (index > 0). Only index 0, which is generated only when
    /// nothing is locked, lands immediately.
    static func waitsBeforeRevealing(colorAt index: Int) -> Bool { index > 0 }
}

/// The naming result as soon as it exists, readable without waiting.
@available(iOS 26.0, *)
private final class ArrivedNames: @unchecked Sendable {
    nonisolated deinit {}
    private let lock = NSLock()
    private var naming: PaletteGenerator.Naming?
    func set(_ value: PaletteGenerator.Naming) { lock.lock(); naming = value; lock.unlock() }
    var value: PaletteGenerator.Naming? { lock.lock(); defer { lock.unlock() }; return naming }
}

enum NamingRace {
    /// The task's value if it finishes within `timeout`, otherwise nil. The
    /// task itself keeps running either way.
    static func firstResult<T: Sendable>(of task: Task<T, Never>, within timeout: Duration) async -> T? {
        // Unstructured on purpose: a task group would wait for the slow
        // child, and awaiting another task's value ignores cancellation.
        await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
            let once = OnceBox<T?>(continuation)
            let sleeper = Task {
                try? await Task.sleep(for: timeout)
                once.resume(nil)
            }
            Task {
                once.resume(await task.value)
                sleeper.cancel()
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
