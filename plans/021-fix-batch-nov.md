# Plan 021 — Fix batch (Nov 2026): naming, copy, Generate, widgets

> **For agentic workers:** use superpowers:subagent-driven-development. Steps use `- [ ]`. Each track is independent and runs in its own worktree; the controller merges them into `feature/fix-batch-nov`.

**Goal:** Fix the ten items reported on 2026-11-20 (list at the bottom).

**Architecture:** No new architecture. `AppData` stays the single source of truth for palettes/colors. iOS 26-only APIs stay behind `Palettes/Compatibility/` shims. Widgets read only the app-group `WidgetSnapshot` (+ app-group defaults where noted).

## Global constraints
- Do not hand-edit `.pbxproj` (synchronized groups); new files are auto-included.
- Keep `PaletteViewModel`'s `colors` / `hexCodes` / `colorNames` arrays index-aligned.
- Every new class gets `nonisolated deinit {}` (see CLAUDE.md).
- Commit by explicit path (`git commit -- <paths>`); never `git add -A`. Pass your own `-derivedDataPath` to xcodebuild.
- Tests: flat `PalettesTests/<Subject>Tests.swift`, `@MainActor final class …: XCTestCase`, `@testable import Palettes`. Run only the suites you touch with `-only-testing:PalettesTests/<Suite>`.
- Simulator FoundationModels is unavailable: on the simulator `makeBrief` uses `PaletteBrief.heuristic`, names use the fallback. Tests must cover the heuristic paths; model-path changes are verified by reading.
- Do not touch `Palettes/App/MyApp.swift`, `FilmStage.swift`, `HeaderOrbStage.swift`, `marketing/`, `.scratch/app-icon/` (user's uncommitted work).

## User decisions (2026-11-20)
1. Edited color renames only if its current name still looks auto-generated; names the user typed stay.
2. First quick-copy shows a dialog to pick the default: colors → HEX / RGB; palettes → HEX, RGB, CSS, SCSS, SwiftUI, Tailwind, JSON, Coolors URL. Remembered, changeable in Settings.
3. Vibe text must drive both the generated colors AND the palette name ("ocean sunset" → blues/oranges, a name that relates to ocean/sunset).
4. Small Favorite Colors widget: 2×2 grid of four tiles, colors only.

---

## Track A — Naming & copy (sim: iPad Pro 11-inch (M4) 4139CFC6-0A20-423A-9FEA-E829EBE76113)

### A1: Unified Title Case for names
**Files:** new `Palettes/Utilities/NameCase.swift`; `Palettes/Utilities/HEXParser.swift` (ColorNamer); `Palettes/App/AppData.swift`; `PalettesTests/NameCaseTests.swift`.
- [ ] `nonisolated enum NameCase { static func titled(_ s: String) -> String }`: trims/collapses whitespace; uppercases the first letter of each word, keeps the rest of the word as typed if it already has an uppercase letter (so "iPhone Blue", "UI Red" survive), lowercases nothing else; minor words (`of, and, the, in, on, at, to, a, an, or, for`) stay lowercase unless first/last. Hyphenated parts each capitalized ("blue-green" → "Blue-Green").
- [ ] Apply in `ColorNamer.uniqueNames` to `preferred` (AI) names before uniqueness checks, and to palette titles where `AppData` creates/renames palettes and colors (`addPalette`, `addColor`, rename paths, `uniqueColorName(preferred:)`). Grep every place a name is written through AppData and cover it.
- [ ] One-time migration in AppData load: names that are entirely lowercase (`name == name.lowercased()` and contains a letter) get `NameCase.titled`, persisted via the normal debounced write. Gate with a UserDefaults flag (`didTitleCaseNames.v1`).
- [ ] Tests: casing rules, minor words, hyphen, preserved acronyms, ColorNamer preferred names titled.

### A2: Edited color name follows the color when auto-named
**Files:** `Palettes/Views/Components/ColorComposer.swift`, `Palettes/Views/Color/ColorEditView.swift`, `Palettes/Views/Palette/Editor/PaletteEditor.swift` (composer call ~L567), tests.
- [ ] Replace `namesFollowColor: Bool` with a naming policy: `.follows` (new colors, today's behavior), `.keeps`, `.followsIfAuto(originalHex:)`.
- [ ] `.followsIfAuto`: on appear, the name counts as auto when it case-insensitively equals `ColorNamer.name(forHex: originalHex)` OR `ColorNamer.name(forHex: originalHex, avoiding: <library names minus this color's own>)`, OR it equals the nearest dictionary entry name for the original hex. Put this predicate in a testable static func (e.g. `ColorNamer.looksAutoNamed(_ name:, hex:, taken:)`). If auto → behaves like `.follows` (typing makes it custom, clearing hands it back); otherwise `.keeps`.
- [ ] When following, the suggestion must not collide with the color itself: exclude its own current name from `taken` (check `AppData.uniqueColorName`).
- [ ] Edit Color and the palette editor's per-color composer use `.followsIfAuto`; New Color keeps `.follows`.
- [ ] Saving an edited palette color must still keep arrays aligned and sync to library (`syncEditedPaletteColor` in PaletteDetailView) — verify the new name propagates.
- [ ] Tests for `looksAutoNamed`.

### A3: First-copy default dialog + Settings
**Files:** new `Palettes/Utilities/CopyPreference.swift`; copy sites: `Views/Color/ColorsView.swift` (~L294 onCopy), `Views/Palette/PaletteView.swift` (~L336 onCopy), `Views/Components/Cells/ColorCellBig.swift` (~L110), plus any other one-tap copy (grep `copyToClipboard(` and `onCopy`); `Views/Settings/SettingsView.swift`; `Shared/WidgetCopyText.swift` if widgets copy.
- [ ] `CopyPreference`: `ColorCopyFormat { hex, rgb }`, `PaletteCopyFormat { hex, rgb, css, scss, swiftui, tailwind, json, coolorsURL }` stored in app-group UserDefaults (same suite the widget snapshot uses) as optionals; nil = not chosen yet. Text builders reuse `PaletteExporter.export(_:as:)` and the existing "Copy as HEX/RGB" string code (find and reuse, don't duplicate formats).
- [ ] One-tap copy (not the explicit "Copy as HEX/RGB" menu items, which stay as they are): if no preference for that kind, present a `.confirmationDialog` "Choose what Copy copies" with the formats; picking one saves it AND copies; Cancel copies nothing. Afterwards copy silently with the saved format, toast label e.g. "Copied CSS".
- [ ] Put the dialog logic in one reusable modifier/helper so every copy site uses it.
- [ ] Settings: a "Copy" section with two Pickers (Colors, Palettes), including a "Ask next time" option that clears the preference.
- [ ] Widgets: if widget copy buttons exist and copy in-process, make `WidgetCopyText` honor the saved formats (palette formats beyond HEX/RGB need `PaletteExporter`, which is app-only: for those, widgets fall back to HEX and that's acceptable — note it in a comment). Coordinate: Track C must not edit `Shared/WidgetCopyText.swift`.
- [ ] Tests: preference round-trip, formatted output per format.

---

## Track B — Generate (sim: iPhone Duo 26543A3A-FDE7-443A-B9FF-6F83C51E06F1)

### B1: Auto / UI Light / UI Dark produce the same result
**Files:** `Views/Color/GenerateView.swift`, `Managers/{PaletteGenerator,PaletteBuilder,PaletteRefinement,ColorHarmony}.swift`, tests.
- [ ] Diagnose first (superpowers:systematic-debugging). Leads: the `scheme` @State → `performGeneration` (`canChooseMode ? scheme : .auto`, ~L1050); the refine/regenerate path (`refining` ignores `scheme`; a "regenerate" may reuse the old recipe's scheme); `GenerationExperienceView` or onboarding calling `generate` without the scheme; result ordering (HueOrder sorting could hide role order); `interfaceEntries` output vs harmonic output for no-anchor and with-anchor inputs.
- [ ] Write a failing test that shows the user-visible symptom (same hexes/roles across the three modes for the same seed + vibe), fix the root cause, keep the test.
- [ ] Expected after fix: UI Light → light surfaces/background + primary/accent/text roles; UI Dark → dark surfaces; Auto → harmonic palette from the vibe/anchors. Changing the mode on an already-shown result and regenerating must honor the new mode.

### B2: Orb fills only once names are ready (no color switch at the end)
**Files:** `Views/Color/GenerateView.swift` (`arrivedColors`, `onColors`, `applyLateNaming`), `Managers/PaletteGenerator.swift` (`onPartialColors` loop, naming task), `Views/Components/Generation/*`.
- [ ] Find why the colors visibly switch at the end (the late-named `PaletteViewModel` colors/order differ from the partial previews? a re-sort? `arrivedColors` replaced by result colors?). Record the cause in the commit message.
- [ ] Change the flow: the orb stays in its "working" state until names are back (or the naming timeout/fallback fires), then fills with the final colors, in final order, using the existing reveal pacing (`GenerationPacing`). The final colors shown must be exactly the result's colors, so nothing changes after the fill.
- [ ] Keep cancel/timeout behavior; keep onboarding generation working (it shares the generator).
- [ ] Update `GenerationPacingTests`/`PaletteGeneratorTests` as needed.

### B3: Vibe drives colors and palette name
**Files:** `Managers/{PaletteBrief,PaletteGenerator,PaletteNamer}.swift`, `Utilities/ColorVocabulary.swift`, tests.
- [ ] Colors: check `PaletteBrief.heuristic` + model brief map vibe words to hue/tone (e.g. "ocean", "sunset", "forest", "lavender", "coffee", "neon", "pastel"). Multi-concept vibes ("ocean sunset") should yield both hue families: if the brief only carries one `hue`, add an optional secondary hue the builder uses for the accent/complement slots (or choose a scheme that spans both). Ensure the model prompt asks for the hues the words imply.
- [ ] Name: `PaletteNamer.resolvedName` currently drops AI titles that aren't "specific / only name colors present" and falls back to a color-based title, losing the vibe. Pass the vibe in; prefer a title that relates to the vibe words (AI title accepted when it shares a meaningful word/concept with the vibe even if it doesn't name a color); fallback derives a title from the vibe's key words (Title Case via `NameCase` if Track A has landed, else capitalize words locally — controller reconciles) combined with a color word if short (e.g. "Ocean Sunset", "Misty Forest"). Must stay unique against `existingNames`.
- [ ] Tests: heuristic hue for sample vibes; resolvedName keeps vibe-related titles and builds a vibe fallback.

---

## Track C — Widgets (build only; controller verifies on a simulator)

### C1: Jagged palette strips in Favorite Palettes
**Files:** `PalettesWidgets/Common/SwatchStrip.swift`, `PalettesWidgets/Widgets/FavoritePalettesWidget.swift`.
- [ ] Cause (likely): `SwatchStrip` is a 1-px-per-color image stretched with `.interpolation(.none)`; at non-integer band widths and with the rounded clip at short heights, edges land on uneven pixels. Fix: render the strip at the size it is shown — `GeometryReader` + `@Environment(\.displayScale)` → image of exact pixel size with band edges rounded to whole pixels — still an Image with `fullColorInAccentedModes()` (shapes get recolored in tinted mode). Keep all other callers working (PaletteFace, PaletteListFace, ColorFace, favorites).
- [ ] Clip with a continuous rounded rect that is pixel-aligned; no visible stair-steps.

### C2: Large palette widget shows up to 6 names before "+N more"
**Files:** `PalettesWidgets/Common/PaletteListFace.swift`.
- [ ] Show all rows when ≤ 6; otherwise 6 rows then "+N more" (N = count − 6). Make it fit in `.systemLarge` (shrink the band area / row spacing if needed; no clipping of the last row on the smallest large-widget size).

### C3: Choose which favorites the favorite widgets show
**Files:** `PalettesWidgets/Widgets/{FavoritePalettesWidget,FavoriteColorsWidget}.swift`, new `PalettesWidgets/Configuration/FavoritesWidgetIntents.swift`, `WidgetEntities.swift` (reuse existing entities).
- [ ] Switch both to `AppIntentConfiguration` keeping the SAME `kind` strings. Intent: `Show` = `Favorites` (default, today's behavior) or `Chosen`; `Chosen` shows an array parameter of palette/color entities (size limit = widget capacity; order as picked). Entity queries should list favorites first then the rest.
- [ ] Missing/deleted chosen items are skipped; if none remain, fall back to favorites.

### C4: Small Favorite Colors widget
**Files:** `FavoriteColorsWidget.swift`.
- [ ] Add `.systemSmall`: 2×2 grid of 4 tiles, colors only (no text), rounded tiles. Small widgets ignore `Link` → use `.widgetURL` to open the Colors tab (check `WidgetLink` for an existing route; add `colors` if needed, and handle it in the app's link inbox — coordinate: that app-side handler is the ONE app file Track C may touch). Accessibility label lists the color names.

---

## Order
Tracks A, B, C run in parallel (no shared files). Exception: B3's title casing uses a local helper; after merge the controller swaps it for `NameCase.titled`. Each task: implement → build → focused tests → commit → Opus review.

## Reported items (2026-11-20)
1. Color name changes after edit → A2
2. Capitalized names → A1
3. First-copy default dialog → A3
4. Generate modes identical → B1
5. Orb fills after names → B2
6. Vibe ↔ colors + name → B3
7. Jagged Favorite Palettes strips → C1
8. 6 names in large palette widget → C2
9. Choose favorites in widgets → C3
10. Small Favorite Colors widget → C4
