# Sheets r4: dev's layout as the base (019)

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Sonnet implements each task; Opus reviews each task and the final branch. Steps use `- [ ]`.

**Goal:** Rebuild New Palette / Edit Palette on the layout of the `dev` branch's New Palette sheet, restyle the color editor with dev's glass cards (no color wash), add Scan as a picker mode, and land the five motion fixes from the plan 018 audit.

**Why:** After plan 018 the user reviewed the sheets on the simulator (2026-10-11). They like dev's sheet design better than the 018 palette editor and asked to use it as the base, keeping the 018 upgrades that fit.

**Branch:** `feature/sheets-redesign` (on top of plan 018, `877bba2`). Plan 018's Global Constraints still apply (iOS 17.0 target, no `project.pbxproj` edits, AppData single source of truth, button rule, motion spec), except where this plan overrides them.

## Decisions (user, 2026-10-11)

| # | Decision |
|---|---|
| D1 | New Palette follows dev's layout plus the upgrades that fit: the 018 picker in Pick, tap a row or band to edit, drag to reorder, ✓/+ buttons, draft + discard prompt. |
| D2 | Kept from 018: Harmonies (as a source), Photo pins (inside Scan), strip reorder. **Dropped:** start tiles, Start Blank, Generate shortcut. |
| D3 | The add area is a **pinned bottom panel**: palette strip on top, name + "Added Colors" rows scroll in the middle, the add panel (source switch Pick · Scan · Library · Harmony) is fixed at the bottom so drag surfaces never sit in a scroll view. |
| D4 | New Color / Edit Color: Scan is a 4th picker mode — Spectrum · Grid · Sliders · Scan. The eyedropper button on the swatch is removed. |
| D5 | Styling for both sheets: plain sheet background (no color wash), content in dev-style liquid-glass cards; the swatch stays the hero. |
| D6 | Fix the five plan-018 audit findings (see Task 5). |

Unchanged from 018: Edit Palette is the same editor in edit mode (draft, Cancel discards, ✓ saves); 2-color minimum; inline duplicate notices; blank name uses the `PaletteNamer` suggestion; button rule (+ add, ✓ create/save) on every iOS.

## Dev reference (read with `git show dev:<path>`)

- `Palettes/Views/Palette/NewPaletteView.swift` — glass name field (`.font(.system(size: 18, weight: .medium))`, `.padding()`, `.liquidGlass(.regular, in: .rect(cornerRadius: 16))`); 56 pt strip in a 16 pt rounded clip with a "N colors" caption; empty preview = glass box with `swatchpalette` symbol and "Add at least 2 colors to build your palette"; "Added Colors" header (`.subheadline.weight(.semibold)`, secondary); rows = 40 pt rounded-10 swatch, name 14 medium, hex 12 mono + RGB 10 mono secondary, `minus.circle.fill` hierarchical red remove, row padded 10 in `.liquidGlass(.regular, in: .rect(cornerRadius: 14))`.
- `Palettes/Views/Components/ColorInputView.swift` — segmented source switch with `.sensoryFeedback(.selection, trigger: source)`; Scan: glass photo area 200 pt (`scaledToFill`, rounded 20, "Tap to pick a color" capsule), Camera / Library buttons (`.liquidGlass(.interactive, in: .rect(cornerRadius: 14))`, `.subheadline.weight(.medium)`, 12 pt vertical padding); True Tone alert once (`@AppStorage("didAcknowledgeTrueToneWarning")`, title "Turn Off True Tone", message as in dev); tuning sliders in a glass card (padding 14, corner 20); "Add" button `.glassButton(prominent: true)`.
- `Palettes/Views/Components/InteractiveColorPicker.swift` — 120 pt swatch, glass name field, glass HEX/RGB fields (corner 12).

Helpers on this branch: `.liquidGlass(_:in:)` (`Palettes/Compatibility/LiquidGlassCompat.swift`, `.regular` / `.interactive`), `.glassButton(prominent:)`, `.softScrollEdge()`.

---

### Task 1: Color editor restyle — plain background, glass cards, no eyedropper, stable header

**Files:** `Palettes/Views/Components/ColorComposer.swift`, `Palettes/Views/Components/ColorPicking/SpectrumPad.swift`

- [ ] Remove `ColorWashBackground` from `ColorComposer`; background is `Color(.systemGroupedBackground)`. (`ColorWashBackground` stays in `SheetComponents.swift` only if something else uses it; otherwise delete it.)
- [ ] Replace the scrolling `Form` with a `ScrollView` of dev-style glass cards (horizontal padding 16, 16 pt between cards): **Tag** card (only when `tag != nil`; a row "Tag" + value + chevron, whole card is the button), **Fine-tune** card (section title above it in dev's header style; the same three `AdjustmentSlider`s; padding 14; `.liquidGlass(.regular, in: .rect(cornerRadius: 20))`; footer text below), **Values** card (HEX and RGB fields styled as dev's glass fields, corner 12). Keep `.softScrollEdge()` on the ScrollView and the focus/animation behavior from plan 018 Task 6 (sections opt out of the focus animation).
- [ ] Remove the eyedropper `Menu` from the swatch, and the photo-library / camera / sampler state that only it used (Scan mode in Task 2 replaces it). Remove the 46 pt trailing padding that made room for it.
- [ ] **Audit #1:** the notice line must not move the picker. Give the header a fixed notice row (always laid out, `.frame(height:)` matching one footnote line, text faded in/out with `.opacity`), or overlay the notice inside the swatch's bottom-trailing corner. Either way, inserting or removing a notice changes no layout.
- [ ] **Audit #3:** the Spectrum thumb grows from 24 to 32 pt while a finger is on the field or the saturation track (`.spring(duration: 0.2, bounce: 0)`; no size change under Reduce Motion). The position still tracks 1:1 with no animation.
- [ ] Build on both simulators; full suite; commit `Color editor: dev-style glass cards, no wash, stable notice row`.

### Task 2: Scan as a 4th picker mode

**Files:** create `Palettes/Views/Components/ColorPicking/ScanPicker.swift`; modify `ColorPickerPanel.swift`, `ColorComposer.swift`.

- [ ] `ColorPickerMode.scan` (title "Scan"). `ColorPickerPanel` gets `var allowsScan = false`; the segment only shows when true. `ColorComposer` passes `allowsScan: true`; `HarmonyPage` and the palette add panel's Pick source don't.
- [ ] `ScanPicker(color: Binding<Color>, onPick: (Color) -> Void)`:
  - No photo yet: dev's glass photo area (same height as the Spectrum field, 180 compact / 220 regular) with a `photo.on.rectangle` symbol and "Take or choose a photo", and under it the two dev buttons **Camera** (`camera.fill`, only when a camera exists) and **Library** (`photo.on.rectangle`, `PhotosPicker`).
  - Photo chosen: show it aspect-fill in that area (rounded 20) with one draggable marker (30 pt ring, like a photo pin) placed on the dominant color (`ImageColorExtractor.extractDominantRGB`, then `PhotoPinLocator.locate`). Dragging the marker (or touching anywhere on the photo) samples with `PixelSampler.color(at:radius: 2)` 1:1, no animation, and calls `onPick`. A small "Change Photo" glass capsule in the corner reopens Camera/Library choices.
  - Downsample the photo to 2048 px on the long side before use (reuse the helper from plan 018 Task 13 — move it somewhere shared, e.g. an `UIImage` extension, rather than duplicating it).
  - True Tone alert once per install when Scan is first shown (dev's `@AppStorage("didAcknowledgeTrueToneWarning")`, same title and message).
- [ ] The picker remembers its mode (`@AppStorage("colorPickerMode")`); if the stored mode is `.scan` and the host doesn't allow it, fall back to `.spectrum`.
- [ ] Tests: any pure geometry/helper you add (e.g. downsample sizing).
- [ ] Build on both simulators; full suite; commit `Scan joins the color picker`.

### Task 3: Palette editor on dev's layout with a pinned add panel

**Files:** modify `Palettes/Views/Palette/Editor/PaletteEditor.swift`, `PaletteStripEditor.swift`; create `Palettes/Views/Palette/Editor/PaletteAddPanel.swift` and `PaletteColorRow.swift`; delete `PaletteStartTiles.swift`; refactor `HarmonyPage.swift` and `PhotoPinsPage.swift` into embeddable views (they are no longer pushed pages).

Layout (top to bottom, sheet background `Color(.systemGroupedBackground)`):
1. **Strip (pinned):** `PaletteStripEditor` at 72 pt, 16 pt rounded clip, horizontal padding 16; caption "N colors" under it (dev style). Remove the strip's **+ tile** and `addMenu` (the add panel replaces it); keep tap → edit, drag to reorder, context menu (Edit, Duplicate, Tag…, Remove). Empty draft: dev's glass empty preview ("Add at least 2 colors to build your palette", `swatchpalette`).
2. **Middle (scrolls, `.softScrollEdge()`):** dev's glass name field (placeholder = the `PaletteNamer` suggestion, or "Palette Name"), then "Added Colors" header and one dev-style row per color (`PaletteColorRow`): tapping the row or its swatch pushes the color editor (existing `.edit(id)` route), `minus.circle.fill` removes (with the existing Undo toast), the role (if any) shows as a small capsule after the name.
3. **Add panel (pinned bottom):** a glass card (corner 24, top padding 12) holding a segmented switch **Pick · Scan · Library · Harmony** (`.sensoryFeedback(.selection, trigger:)`, remembered with `@AppStorage("paletteAddSource")`) and the selected source. Height: about 46% of the available height, minimum 300 pt; content inside lists scrolls within the panel.
   - **Pick:** a compact swatch row (48 pt swatch, name field, hex), `ColorPickerPanel(allowsScan: false)`, the duplicate notice ("Already in this palette"), and a **+ Add to Palette** button (`.glassButton(prominent: true)`, disabled on duplicates). After adding, the picker moves to a new random starter so the next color is ready.
   - **Scan:** the photo-pins view from Task 13, embedded: Camera / Library buttons while empty; with a photo, draggable pins + live mini strip + **+ Add N**. Appends (never replaces).
   - **Library:** the library multi-select (search + checkmarks, existing colors shown as added) with **+ Add N**; if the library is empty, a short empty state.
   - **Harmony:** base-color chips (the palette's colors; the Pick color when the palette is empty) and the five harmony strips for the chosen base; tapping a strip appends it (skip existing hexes; toast "Already in this palette" when nothing is added).
- Remove: start tiles, Start Blank, the Generate tile/route, `.harmony`/`.photo` routes, `PaletteStartTiles.swift`.
- Keep: toolbar (✕ Cancel with discard prompt when `draft != original`; ✓ Create/Save disabled until 2 colors), `interactiveDismissDisabled`, RoleList routes and tag remap, duplicate alerts in the New Palette wrapper, Edit Palette wrapper save.
- [ ] Build on both simulators; full suite; commit `Palette editor on dev's layout with a pinned add panel`.

### Task 4: Simulator pass and visual polish

- [ ] Controller runs New Color (each picker mode incl. Scan with a photo), Edit Color, New Palette (each add source, reorder, row edit/remove/undo), Edit Palette (Cancel discards, ✓ saves) on iOS 27 and, with permission, iOS 17.5; fixes go back to the implementer.

### Task 5: Motion fixes from the plan 018 audit

**Files:** `PaletteStripEditor.swift`, `PaletteEditor.swift`, `ColorPickerPanel.swift`, `PhotoPinsPage.swift` (or its embeddable successor).

- [ ] **Audit #2 (Reduce Motion):** under Reduce Motion, no layout animation anywhere in these sheets — `settle`, `reshuffle`, the editor's `appendAnimation` and the picker mode switch become `nil` for layout, and only `.opacity` transitions remain.
- [ ] **Audit #4:** a light success haptic on a completed drop — band reorder (`.sensoryFeedback(.impact(weight: .light), trigger: dropCount)`) and when a photo pin is released (`.impact(weight: .light, intensity: 0.6)`).
- [ ] **Audit #5:** when an empty palette receives several colors at once (Scan, Library, Harmony), bands and rows enter with a 40 ms stagger (`.spring(duration: 0.35, bounce: 0)` per item, opacity + 8 pt upward offset); no stagger when one color is added, and opacity only (no offset, no stagger) under Reduce Motion.
- [ ] (#1 and #3 land in Task 1.)
- [ ] Build on both simulators; full suite; commit `Motion: reduce-motion layout, drop haptics, first-fill stagger`.

### Task 6: Wrap-up

- [ ] Update `plans/README.md` (018 DONE → superseded in part by 019; 019 row), plan 017 status line, `graphify update .`, delete the throwaway simulators `sheets-018` and `sheets-018-ios17`.
- [ ] Final whole-branch Opus review (with the minor-findings list from `.superpowers/sdd/progress.md`), one fix wave, then finishing-a-development-branch.
