# Harmony-Guided Generation & Color Role Tags — Design

**Date:** 2026-07-21
**Status:** Approved design, pending implementation plan
**Branch:** `feature/harmony-and-color-roles` (off `dev`)

## Goal

Two related features that make Palettes useful for crafting brand identities and UI color systems:

1. When one or more existing colors are selected and **no vibe** is given, generation should produce a deliberate, color-theory-grounded complementary palette instead of relying on a vague AI prompt.
2. Palette colors can be tagged with UI/UX **roles** (Primary, Secondary, Accent, …) plus app-wide custom tags, and those roles drive export variable names and search.
3. **Vibe-driven** generation gains real color-theory prompting and post-validation, and **image color extraction** stops missing small-but-significant accent colors.

## 1. ColorHarmony engine

New file: `Palettes/Managers/ColorHarmony.swift`. Pure HSB math, no AI, no `@available` gate, fully unit-testable.

```swift
enum HarmonyScheme: String, CaseIterable {
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic
}

struct HarmonySlot {
    let hue: CGFloat          // 0..1
    let saturation: CGFloat
    let brightness: CGFloat
    let role: ColorRole?      // suggested UI role for this slot
}

enum ColorHarmony {
    /// Resolves `.auto` to a concrete scheme, then produces `count` slots
    /// (excluding the locked base colors, which occupy the first positions).
    static func plan(
        baseHexes: [String],
        size: Int,
        scheme: HarmonyScheme,
        seed: UInt64
    ) -> HarmonyPlan   // { resolvedScheme, slots: [HarmonySlot], roleForBase: [ColorRole?] }
}
```

### Auto-pick heuristics (resolved deterministically from base colors + size + seed)

- Base saturation < 0.12 (near-neutral) → **monochromatic** ladder plus one saturated accent slot.
- Two or more locked colors → measure their hue relationship; if roughly opposite → complementary family, if adjacent (≤ 40°) → analogous, otherwise split-complementary.
- Single saturated base, size ≤ 4 → complementary or analogous (seed-dependent pick).
- Single saturated base, size ≥ 5 → split-complementary, and reserve two slots for neutrals: one light (Background: base hue, sat ≤ 0.08, brightness ≥ 0.94) and one dark (Text: base hue, sat ≤ 0.20, brightness ≤ 0.22).

### Variation

A `seed` (random per generation run) drives small jitter: ±6° hue, ±0.06 saturation, ±0.05 brightness per slot, and breaks ties in scheme selection. Same seed → identical plan (testable); regenerate → fresh but always harmonious results.

## 2. PaletteGenerator integration

`PaletteGenerator.generate` gains a `scheme: HarmonyScheme = .auto` parameter.

- **No vibe, base colors present:** compute the harmony plan, convert slots to hex targets, and prompt the model with them: each target must be refined only slightly (±8° hue, small sat/brightness moves) and given an evocative name. The model polishes; the structure is deterministic.
- **Vibe present:** the flow is upgraded, not just re-prompted:
  - **Instructions** gain concrete color-theory guidance: name a harmony strategy that fits the vibe, spread lightness across the palette (at least one light and one dark color for sizes ≥ 4), keep neighboring colors clearly distinct, and prefer saturated accents over uniformly muted output. The chosen scheme (if not auto) is stated in the prompt.
  - **Post-validation:** after collection, the result is checked with existing utilities — every pair of colors must be ≥ 12 CIEDE2000 apart (`ColorNamer.perceptualDistance`) and the palette must span a minimum brightness range for sizes ≥ 4. Colors failing the distinctness check are dropped and the gap is filled by `fillToTarget` using a harmony plan seeded from the *model's* colors, so repairs stay in the vibe's family rather than golden-ratio drift.
  - The vibe + base-colors combination gets the same treatment; locked colors remain verbatim.
- **`fillToTarget` fallback** and the **simulator mock** consume harmony slots instead of golden-ratio hue rotation, so offline/fallback output has the same designed structure. `fillToTarget` keeps its current signature plus a `plan:` parameter; when no plan exists (pure-vibe path) it falls back to the existing rotation.
- Streaming behavior (`onPartialColors`) is unchanged.

## 3. Harmony override UI

In `GenerateView`, once at least one base color is selected, a compact scheme control appears (menu presenting Auto + the five schemes, Auto default). Selection is per-generation state, not persisted. Visual language follows the apple-design skill (glass materials, spring transitions); exact motion values decided during implementation with the find-animation-opportunities / improve-animations skills.

## 4. Role tags — data model

```swift
struct ColorRole: Hashable {
    let name: String          // display name, e.g. "Primary" or custom
    var slug: String          // kebab-case, e.g. "primary"
}
```

- `PaletteColor` gains `var role: String? = nil` (stores the role name; `nil` = untagged). One role per color.
- Built-in defaults (ordered): Primary, Secondary, Accent, Background, Surface, Text, Error, Success, Warning, Border.
- **Persistence:** `StoredPalette` gains `var colorRoles: [String] = []` — index-aligned with `hexCodes`/`colorNames`, empty string = untagged. Inline default keeps it CloudKit-compatible; `PaletteViewModel`'s zip-init pads missing entries with `nil` exactly like hex/name padding.
- **Custom tag library (app-wide):** new `@Model final class StoredTag { var id: UUID; var name: String; var sortIndex: Int }` (inline defaults, CloudKit-safe). `AppData` publishes `customTags: [String]`, persists via the existing debounced write-back, and de-duplicates case-insensitively against built-ins and each other. Renaming a tag rewrites the role string on every palette color using it; deleting clears it.

## 5. Role tag UI

- **Badge:** palette detail swatch rows show a small capsule badge with the role name when tagged.
- **Picker:** tapping the badge area (or a context-menu item on the swatch) opens a role picker sheet/menu: built-in roles, custom tags, "New tag…" text entry (creates in the app-wide library), and "Remove tag".
- **Uniqueness within a palette:** assigning a role already held by another color in the palette moves the role to the newly chosen color (old color becomes untagged). No confirmation dialog — reassigning back is one tap.
- Tag management (rename/delete custom tags) lives in a small "Manage tags" section reachable from the role picker.

## 6. Exports

`PaletteExporter`: when a color has a role, its slug becomes the variable name in CSS (`--color-primary`), SCSS (`$primary`), Tailwind, JSON, and SwiftUI outputs; untagged colors keep the existing name-derived slugs. Collisions (e.g. a custom tag equal to another color's name) run through the existing `uniqueSlugs` pass. Plain-hex, SVG, and Coolors formats are unaffected.

## 7. Auto-assign roles on generation

The harmony plan carries suggested roles; the generated `PaletteViewModel` arrives pre-tagged: first base color → Primary, second base → Secondary, main complement slot → Accent, light neutral → Background, dark neutral → Text. Sizes too small for all roles assign in that priority order. Users can retag freely afterwards.

## 8. Tag-based search & filtering

In `SearchView`, following the existing hue-category filter pattern:

- **Text search:** the query also matches role names — searching "primary" or a custom tag name surfaces palettes containing a color tagged with it (case-insensitive, in `filteredPalettes`).
- **Browse filtering:** alongside the existing hue chips, a row of **tag chips** (built-in roles that are in use, plus in-use custom tags; multi-select like hues). Selected tags narrow the palette browse list to palettes containing at least one color with a selected tag. Colors themselves are untagged (roles live on palette colors), so tag chips apply to the palettes section only.
- Chips only appear when at least one tagged color exists in the library, keeping the UI clean for users who don't use tags.

## 9. Image color extraction improvements

`ImageColorExtractor.extractColors` currently misses small-but-significant color areas: the 80×80 downsample leaves accents only a handful of pixels, k-means runs in raw RGB (vivid accents get absorbed by large muted clusters), and results are ranked purely by cluster size. Changes:

- **Higher-resolution sampling:** downsample to 160×160 (25,600 px) for multi-color extraction, so small areas retain enough pixels to form clusters. `extractDominantRGB` keeps 80×80 (single dominant color doesn't need it).
- **Perceptual clustering space:** convert pixels to **Lab** before clustering and run k-means there (reusing the existing Lab conversion behind `ColorNamer.perceptualDistance`, extracted into a shared helper). Distances then reflect perceived difference, so distinct accents form their own clusters instead of merging into large muted ones.
- **Salience ranking instead of raw size:** score each cluster by `pixelShare × (0.5 + chroma)` — a vividness-weighted share, where chroma is the cluster centroid's Lab chroma normalized to 0…1. Large areas still win overall, but a small saturated accent outranks a slightly larger gray region. Rank and truncate by this score.
- **Distinctness-aware dedup:** keep the CIEDE2000 < 10 merge, but when two clusters merge, the survivor is the higher-salience one (not merely the earlier/larger one).
- **Denoise guard:** clusters below 0.5% pixel share are ignored as noise/JPEG artifacts, so the salience boost can't surface speckle.

`extractDominantRGB` and `PixelSampler` (eyedropper) behavior is unchanged.

## 10. Testing

- `ColorHarmonyTests`: scheme math (complement is ~180° from base, split ±150°/±210°, etc.), auto-pick heuristics per branch above, determinism for a fixed seed, neutral-slot placement at size ≥ 5.
- `PaletteViewModel` / persistence round-trip tests for `colorRoles` (including legacy records with missing arrays).
- `PaletteExporterTests`: tagged variable names per format, collision handling, untagged fallback.
- Search matching tests: query-by-role-name and tag-chip filtering over palettes (extract the pure matching logic if needed for testability).
- Extraction tests (extending `ImageColorSampleTests`): synthetic images where a small saturated patch (~2–4% of area) on a large muted background must appear in the extracted set; Lab clustering separates two perceptually distinct but RGB-close colors; sub-0.5% speckle is not extracted.
- Vibe post-validation tests: palettes with too-similar colors are repaired to meet the ≥ 12 ΔE floor; brightness-range rule enforced at size ≥ 4 (validation logic exposed as a pure function).
- Generator fallback test: `fillToTarget` with a plan produces slot-matching colors.

## 11. Out of scope

- Multiple tags per color.
- Persisting the scheme override between sessions.
- Saliency/attention-model-based extraction (e.g. Vision framework region analysis) — the Lab + salience-ranking approach is expected to cover the reported gaps without it.
