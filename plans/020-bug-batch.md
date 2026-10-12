# Plan 020 — Bug batch: onboarding, generate, sheets, library perf

> **For agentic workers:** use superpowers:subagent-driven-development (or executing-plans). Steps use `- [ ]`. On approval, copy this file to `plans/020-bug-batch.md` and add a row to `plans/README.md`.

**Goal:** Fix the 20 reported bugs/polish items across onboarding, Generate, palette/color sheets, Settings access and Colors-tab performance.

**Architecture:** No new architecture. Changes stay inside existing views; `AppData` remains the single source of truth. iOS 26-only APIs stay behind `Palettes/Compatibility/` shims. Palette editor + color composer get ONE shared "wide layout" predicate so iPhone landscape, iPad and Duo use the same layouts.

**Tech Stack:** SwiftUI (iOS 17 target), SwiftData/CloudKit, FoundationModels, App Intents, XCTest.

## Global constraints
- Do not hand-edit `.pbxproj` (synchronized groups). Keep `PaletteViewModel` arrays aligned.
- Branch: new feature branch off `dev` (feature → dev → staging → main). Current branch `feature/sheets-redesign` has landed work; branch from it only if it is not yet merged to `dev`.
- Build/test: `xcodebuild … -destination "platform=iOS Simulator,name=<SIM>"` (target iOS 27, iPhone 17 Pro, use a throwaway sim — see memory *build-environment*). Run `graphify update .` after code changes.
- Tests live flat in `PalettesTests/<Subject>Tests.swift` (`@MainActor final class …: XCTestCase`, `@testable import Palettes`).

## Decisions I made (flag if wrong)
1. **Generate modes:** keep only `Auto`, `UI Light`, `UI Dark`. Harmony schemes are already inferred from the vibe text (`PaletteBrief.heuristic`, model brief) and New Palette's Harmony tab covers manual use.
2. **Settings button:** add to Colors, Generate, Search (root pages). NOT on pushed detail pages (Palette/Color detail) — a gear there is odd. Say so if you want them too.
3. **Camera preview bug (#1):** the code has no yellow/diagonal drawing, so this starts with a repro step before any fix.
4. **Palette detail → Colors glitch (#3):** cause is not a code path (no code jumps tabs); fix is tab-bar chrome + stack reset + first-mount cost, verified on device.

## File map (primary touch points)
| Area | Files |
|---|---|
| Onboarding | `Views/Onboarding/{OrbCameraPreview,OnboardingCameraFlow,OnboardingInterimSteps,OnboardingGeneration,IslandMorph}.swift`, `Managers/PaletteGenerator.swift` |
| Generate | `Views/Color/GenerateView.swift`, `Managers/{PaletteBrief,PaletteGenerator,PaletteBuilder}.swift`, `Managers/ColorHarmony.swift` |
| Naming | `Utilities/HEXParser.swift` (ColorNamer), `Utilities/ColorVocabulary.swift`, `Managers/PaletteNamer.swift` |
| Sheets | `Views/Palette/Editor/{PaletteEditor,PaletteStripEditor,PaletteAddPanel,HarmonyPickerView,LibraryPickerView,SwatchCard}.swift`, `Views/Components/{ColorComposer,PaletteEditSheet}.swift` |
| Settings | `Views/Color/ColorsView.swift`, `GenerateView.swift`, `Views/Main/SearchView.swift`, new `Views/Settings/SettingsToolbarButton.swift` |
| Perf | `Palettes/AppInfo.plist`, `Views/Components/Cells/ColorMorphCard.swift`, `Selection/{MorphingCardGrid,SelectionCheckmark}.swift`, `Views/Color/ColorsView.swift`, `Views/Main/PaletteTabView.swift` |
| Siri | `Intents/{GeneratePaletteIntent,PalettesShortcuts,PaletteEntity}.swift`, `App/AppData.swift` |

## Order / dependencies
Phase A (quick, independent) → B (Generate) → C (sheets; C1 shared predicate first, then C2–C5) → D (perf/glitch) → E (onboarding, Siri). Tasks within a phase are independent unless noted. Commit after each task.

---

## Phase A — Small independent fixes

### Task A1: Generate labels + remove photo option + mode filter (#4 label, #6, #19-ish)
**Files:** `Views/Color/GenerateView.swift`
- [ ] Change size menu title `"Palette Size"` → `"Size"` (lines ~529–533, incl. accessibility label).
- [ ] Delete photo option: `imageMenuButton` (~844–923) and its call in `generationOptions` (~562); state `selectedImage`, `photosPickerItem`, `showPhotoPicker`, camera picker (~24–27, ~933); image branch in `performGeneration` (~1028–1049); simplify `hasInput`, `canGenerateFromSource`, `generationStatusText`, `canChooseMode`, `targetSize`, description copy (~1069).
- [ ] Filter the Mode menu (~536–557) to `[.auto, .uiLight, .uiDark]` (replace `HarmonyScheme.allCases`).
- [ ] Build; manually verify Generate renders with no photo entry and 3 modes.
- [ ] Commit `Generate: drop photo source, trim modes to Auto/UI Light/UI Dark`.

### Task A2: Vibe field keyboard in portrait (#5)
**Files:** `GenerateView.swift:747–773`
- [ ] Repro first on a real iPhone/simulator with *I/O > Keyboard > Connect Hardware Keyboard* OFF (the Simulator suppressing the soft keyboard is the most likely cause — code has no focus bug).
- [ ] If it still fails on device: check the `.liquidGlass(.interactive, in: .capsule)` at ~773 swallowing taps; add `.contentShape(Rectangle())` + `.onTapGesture { vibeFocused = true }` on the container and verify `@FocusState vibeFocused` flips.
- [ ] Commit (or record "simulator-only, no change").

### Task A3: Settings gear on Colors, Generate, Search (#14)
**Files:** create `Views/Settings/SettingsToolbarButton.swift`; modify `ColorsView.swift:~332–370`, `GenerateView.swift:~115–121`, `SearchView.swift:~107–119`.
- [ ] Create a `ToolbarContent`/view reading `@EnvironmentObject var router: SceneRouter`, `ToolbarItem(placement: .topBarLeading) { Button { router.isShowingSettings = true } label: { Label("Settings", systemImage: "gearshape") } }` — copy the exact button from `PaletteView.swift:379–389` and have PaletteView use the shared one too.
- [ ] Colors: hide while `isSelecting` (leading slot is used by `SelectAllButton`).
- [ ] Generate: ensure `router` is injected into the environment there; the nav bar is hidden in portrait while generating, so only show when the bar is visible.
- [ ] Search: add the toolbar (none exists today).
- [ ] Verify: tap gear on each tab opens the existing sheet from `PaletteTabView.swift:66–72`.
- [ ] Commit.

### Task A4: 120 Hz key (#12a)
**Files:** `Palettes/AppInfo.plist`
- [ ] Add `<key>CADisableMinimumFrameDuration</key><true/>` (not present anywhere today).
- [ ] Commit. (Verified in Task D2.)

---

## Phase B — Auto palette size (#4)

### Task B1: "Auto" palette size in the Generate tab (#4)
**Behavior:** the Size menu gets **Auto** as its first option and the default. With Auto, the app picks the count: the model suggests 4–8 colors from the vibe (a richer, multi-part vibe → more colors; a single-color or minimal vibe → fewer); without Apple Intelligence the heuristic falls back to 6. Locked/anchor colors always count (final size is never below the number locked). Picking 2/4/6/8/10/12 behaves as today. The menu row reads "Size · Auto" (the word "Palette" is dropped, see A1).

**Files:** `Managers/PaletteBrief.swift:14–18`, `Managers/PaletteGenerator.swift:25–50,144`, `Views/Color/GenerateView.swift:17,49,514–535,1007,1033–1047,234`, `Intents/GeneratePaletteIntent.swift:~41`; Tests: `PalettesTests/PaletteBriefTests.swift`, `PaletteGeneratorTests.swift`
- [ ] Failing test: add `PaletteBrief.resolvedSize(requested: Int?, locked: Int, suggested: Int?) -> Int` = `max(locked, requested ?? suggested ?? 6)`, clamped to 2…12. Assert `(nil,0,nil)==6`, `(nil,3,5)==5`, `(nil,8,nil)==8`, `(nil,0,20)==12`, `(4,6,nil)==6`, `(10,0,5)==10`. Also: `PaletteBrief.heuristic("calm forest")` has `suggestedSize == nil`.
- [ ] Run `xcodebuild test … -only-testing:PalettesTests/PaletteBriefTests` → FAIL (symbol missing).
- [ ] `PaletteBrief`: add `var suggestedSize: Int?`; add `resolvedSize`. `GeneratedBrief`: add `@Guide(description: "How many colors the palette needs, 4 to 8: fewer for a simple or single-color vibe, more for a rich multi-part one", .range(4...8)) var suggestedSize: Int`; map into `PaletteBrief(model:vibe:)`.
- [ ] `PaletteGenerator.generate(size:)` takes `Int?`; `targetCount = PaletteBrief.resolvedSize(requested: size, locked: locked.count, suggested: brief.suggestedSize)` at `:144`. `PaletteBuilder` already takes a resolved `Int` (`groupCounts(size:scheme:)`), no change.
- [ ] `GenerateView`: `@State paletteSize: Int? = nil` (nil = Auto). Menu: first button "Auto" (checkmark when nil), then `sizeOptions`; value label `paletteSize.map { "\($0) colors" } ?? "Auto"`. Loading placeholder `GenerationSwatchRow(expected: paletteSize ?? 6)`: when Auto, the row grows to the real count as colors arrive. `resetForm` sets nil; `performGeneration` passes `paletteSize` through unchanged.
- [ ] `GeneratePaletteIntent`: pass `nil` when the user gives no size (today it defaults to 6 and rounds to even).
- [ ] Tests pass; build; manually generate with Auto using "minimal black and white" vs "autumn market at golden hour" and confirm different counts on a device with Apple Intelligence. Commit `Generate: Auto palette size`.

---

## Phase C — Sheets (designed for iPhone Duo, iPad and iPhone)

### Duo design rules these tasks follow
Sources: [Designing for iPhone Duo (HIG)](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) · Tech Talks [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/) and [111463](https://developer.apple.com/videos/play/tech-talks/111463/) · [Apple DTS thread on reservedRegions](https://developer.apple.com/forums/thread/847888) · [third-party summary](https://blakecrosley.com/blog/designing-for-iphone-duo) (secondary; the HIG page itself returned no body text to my fetch tool, so verify wording there). Existing repo notes: `plans/016-ipad-and-iphone-duo.md`, `Compatibility/FoldCompat.swift`.
1. **Two size classes, not per-device layouts.** Outer display = compact width (wider and *shorter* than other iPhones), inner = regular width. "Avoid fixed widths, breakpoints, or any metrics tied to a specific screen." → **no `width >= 700` or idiom checks**; decide from the container's size and size classes only.
2. **Bars move to the side** on the outer display and on the inner display in landscape (portrait inner = horizontal bars). Sheet toolbar items must be `Label`s (title + symbol; already done in 016 A5). Back/Close = `cancellationAction`, the prominent action (Create/Save) = `topBarPinnedTrailing` (016 Part 3 #5). Content must align to **horizontal safe-area insets** so it is offset from the side bar; full-bleed swatches are OK only if no interactive element sits under the controls.
3. **Sheets:** outer display → side controls (sheets with a single toolbar button may opt out via `toolbarVerticalBehavior`); inner display → centred, horizontal bars; half open → the system slides sheets off the fold automatically.
4. **Fold:** reserved regions are the outer camera, inner camera (when active) and the fold (a *division* region, active only when half open; vertical in book pose, horizontal in table/portrait). Scrollable content does NOT need to avoid it; **interactive elements do**. Split content 50/50 around it; "move related elements together". Existing `Fold`, `GeometryProxy.activeFold`, `onFoldChange`, `FoldSplit`, `FoldAwareGrid` in `FoldCompat.swift` already implement this.
5. **Grids:** prefer an **even** column count, keep outer margins and widen spacing around the hinge → use `FoldAwareGrid` for Library/Harmony colour grids in the editor.
6. **Same hierarchy and functionality on both displays** (people open/close the device constantly) — don't hide the add panel or any feature on the outer display. Table pose: visual on top, touch controls in the bottom half (`FoldSplit` does visual-before-crease, controls-after).
7. **Use the extra width, don't stretch the phone layout** — inner display gets the two-column split.
8. `ArrangementView` (iOS 27.1 SDK) is the system split arrangement; the repo gates 27.1 APIs behind `PALETTES_DUO_SDK` (016 Part 2). **Out of scope here**; build with `AnyLayout` + `FoldSplit` now so a later swap is mechanical.

### Task C1: Shared `SheetLayout` decision (foundation; replaces my earlier width≥700 idea)
**Files:** create `Views/Components/SheetLayout.swift`; Test: `PalettesTests/SheetLayoutTests.swift`
- [ ] Define `enum SheetLayout { case stacked, split }` and a pure `static func resolve(size: CGSize, horizontal: UserInterfaceSizeClass?, minStackedHeight: CGFloat) -> SheetLayout`:
  - `.split` if `size.width > size.height` (landscape-shaped container: iPhone landscape, Duo outer/inner landscape, folded book pose, iPad landscape, Split View halves);
  - `.split` if `horizontal == .regular` and `size.width >= size.height * 0.75` (iPad/Duo-inner portrait with room for two columns — ratio, not points);
  - `.split` if `size.height < minStackedHeight` (the Duo outer display in portrait: compact and wide-short, so the stacked layout would clip — this is the cut-off Library bug); `minStackedHeight` is computed from content (`@ScaledMetric` sum of swatch + name row + add-panel minimum), never a screen constant;
  - else `.stacked`.
- [ ] Failing tests (pure, no UI): `852×393` → split; `393×852` compact → stacked; `1180×820` regular → split; `820×1180` regular → stacked (ratio 0.69 < 0.75), `1024×1366` regular portrait → stacked; a Duo-outer-portrait-like `~430×380` compact with min 520 → split; same size with min 300 → stacked; `size.width == size.height` → stacked; larger `minStackedHeight` (Dynamic Type XXL) flips a borderline size to split.
- [ ] Expose a `SheetLayoutReader` view/modifier measuring the container with `onGeometryChange` (size changes when the device folds/unfolds or the window resizes) and injecting `SheetLayout` plus the active `Fold?` via `GeometryReader` + `onFoldChange` (fold changes don't alter size, per FoldCompat note).
- [ ] Commit.

### Task C2: Edit/New Color landscape (#11, #20)
**Files:** `Views/Components/ColorComposer.swift:86–114,206–236` (shared by `ColorEditView`/`NewColorView`)
- [ ] Replace `usesTwoColumns = isRegular || verticalSizeClass == .compact` with `SheetLayout.split` from C1 (so iPad, Duo outer/inner and iPhone landscape all share the iPhone landscape layout).
- [ ] In split: the left half's swatch uses `.frame(maxWidth: .infinity, maxHeight: .infinity)` so it fills the **full height** of the left half; remove the `maxWidth: 380` cap (columns 50/50, or on a half-open fold use `FoldSplit(fold:)` with the swatch before the crease and controls after it, not across it). Name row + notice overlay the swatch or sit at its bottom so nothing interactive is under the side bar. Keep focus-shrink (`shrunkSwatchHeight`) only for stacked.
- [ ] Right half: controls in a `ScrollView`, aligned to horizontal safe-area insets; Save = `topBarPinnedTrailing`, Cancel = `cancellationAction`, both `Label`s.
- [ ] Verify (Device Hub Xcode 27.1 + sims): Duo outer portrait/landscape, Duo inner portrait/landscape/half-open book + table, iPad both, iPhone landscape; Dynamic Type XL; no interactive element under the fold or side bar.
- [ ] Commit.

### Task C3: New Palette editor — remove Added Colors, subtext, split layout (#7, #16, #17, #18, #19)
**Files:** `Views/Palette/Editor/PaletteEditor.swift` (state 44–65, consts 87/90, 119, `upper(gridMax:)` 265–297, `addedHeader` 299–319, `rowsHeight` 323–327, `addedGrid` 330–357, `add()` 413, caption 229–234, body 115–154), `SwatchCard.swift` (`PaletteColorCard`), `PaletteAddPanel.swift:21–60,137–139`, `LibraryPickerView.swift`
- [ ] Delete `addedExpanded`, `fixedUpperHeight`, `gridContentHeight`, `cardHeight`, `scrollTarget`, `upperShare`, `visibleRows`, `rowsHeight`, `addedHeader`, `addedGrid`, the `gridMax` param and its `onGeometryChange`. Keep `removeColor(id)` (strip remove + undo toast). Delete now-dead `PaletteColorCard`.
- [ ] Subtext under the strip: second caption line `"Tap to edit · long press to remove"` (`.footnote`, `.secondary`), shown only when `!draft.colors.isEmpty`. Behavior already matches (tap → edit at `PaletteStripEditor:197`, long press → context menu with Remove at `:220–225`, reorder drag untouched).
- [ ] Stacked layout (portrait iPhone): strip → name → source picker → add panel; panel `maxHeight: .infinity` with a content-based minimum height (wire `PaletteEditorLayout.panelHeight` floor, unused today) and the whole editor in a vertical `ScrollView` when content exceeds the sheet. **This fixes #18**: Library cards are no longer squeezed to ~0 pt on the Duo outer display.
- [ ] Split layout (C1 `.split`: iPhone landscape, iPad, Duo inner portrait or landscape, Duo outer landscape): **left** = strip (flexible height, vertical), name, subtext, and the colours-so-far; **right** = source picker + `PaletteAddPanel` (Pick · Scan · Library · Harmony). Both columns vertically scrollable (`ScrollView`), 50/50. Half open with an active fold: `FoldSplit(fold:)` puts left column before the crease and the add panel after it (interactive controls never on the crease); table pose (horizontal crease): strip on top, controls on the bottom half.
- [ ] Grids inside the panel (LibraryPickerView, HarmonyPickerView) use `FoldAwareGrid` → even columns, wider gap at the hinge. Pinned Add/Create buttons stay inside horizontal safe-area insets.
- [ ] Hierarchy identical on every display: no feature hidden on the outer display.
- [ ] Verify on the same device matrix as C2, plus Duo outer: Library cards fully tappable.
- [ ] Commit.

### Task C4: Harmony "–" to remove (#8)
**Files:** `Views/Palette/Editor/HarmonyPickerView.swift:118–166`, `PaletteAddPanel.swift:~87–133`, `PaletteEditor.swift:~467`; Test: `PalettesTests/PaletteAddPanelTests.swift`
- [ ] Failing test: pure helper `HarmonyRow.state(for hexes: [String], draftHexes: Set<String>) -> .none | .partial | .all` (uppercased compare, same as `PaletteAddPanel:112`).
- [ ] Row: show `minus.circle.fill` when `.all` (calls `onRemove(hexes)`), `plus.circle` otherwise (adds only the missing hexes; `choose` skips present ones). The control has a title for VoiceOver/overflow ("Remove harmony" / "Add harmony").
- [ ] Plumb `onRemove: ([String]) -> Void` through `PaletteAddPanel` to `PaletteEditor`, which finds draft ids by hex and calls `removeColor(id)` (undo toast reused).
- [ ] Tests pass; commit.

### Task C5: Edit Palette landscape (#13, #20)
**Files:** `Views/Components/PaletteEditSheet.swift:18–22`, `PaletteEditor.swift` (edit mode), `PaletteStripEditor.swift:63,110`
- [ ] Reuse C3's split: `.edit` mode, `.split` → **left** = horizontal bands filling the full height of the left half (strip height param becomes flexible, `nil` = fill), **right** = name field (+ add panel, scrollable); mirrors Edit Color's left-half swatch. Half-open fold: strip before the crease, name/controls after. Same `SheetLayout`, so iPad, Duo and iPhone behave identically.
- [ ] Verify across the matrix. Commit.

---

## Phase D — Library glitch & performance

### Task D1: Palette detail → Colors tab glitch (#3)
**Files:** `Views/Main/PaletteTabView.swift:~134–209`, `Views/Palette/PaletteView.swift:5,92`, `Views/Components/Selection/MorphingCardGrid.swift:~148–182`, `Compatibility/FoldCompat.swift:74–82`
Hypotheses ranked; test each on device with the detail view pushed, then tap the Colors tab.
- [ ] H1: comment out `tabBarMinimizeBehavior(.onScrollDown)` in `tabBarLiquidGlassChrome()`; if glitch vanishes, scope it to root content of each tab instead of the whole `TabView`.
- [ ] H2 (first-mount hitch): `LazyMorphingCardGrid` starts at `viewport == .zero` and re-mounts after geometry. Seed `viewport` from a cached last size (or `UIScreen.main.bounds`) so first frame mounts the right window once.
- [ ] H3: `onFoldChange` fires in `onAppear` with `withAnimation(.smooth)` — only call the action when the fold actually changed, and use `.transaction { $0.animation = nil }` on first call.
- [ ] Regardless: in `PaletteView`, `.onChange(of: selectedTab) { if $1 != .palettes { path = NavigationPath() } }` so leaving the tab resets the stack (keep if UX-acceptable; ask the user if they'd rather preserve the pushed detail).
- [ ] Record before/after screen recording. Commit the smallest fix that works.

### Task D2: Colors tab scroll perf + 120 Hz (#12)
**Files:** `ColorMorphCard.swift:29–172`, `ColorCellBig.swift`, `SelectionCheckmark.swift`, `ColorsView.swift:60–71,247–259`, `MorphingCardGrid.swift:178–197`; Test: `PalettesTests/MorphingCardGridTests.swift`
Profile first: Instruments → SwiftUI + Animation Hitches on a library of ~500 colors, then apply in order and re-measure after each:
- [ ] (a) Confirm 120 Hz key from A4 on a ProMotion iPhone.
- [ ] (b) `ColorMorphCard`: replace dual always-mounted bars (opacity 0/1) with `if isCompact { compactBar } else { regularBottomBar }` + `.transition(.opacity)`; cuts ~4–5 glass layers per card.
- [ ] (c) Remove `.compositingGroup().shadow(radius: 8)` per card (also `ColorCellBig`); if a shadow is needed, put a cheap shadow on a background shape only.
- [ ] (d) `SelectableCardChrome`: make it a no-op (no overlays/scale/animations) when `!isSelecting`.
- [ ] (e) `ColorsView`: cache `displayedColors` in `@State` updated via `onChange` of `appData.colors`/sort/filter instead of recomputing in every body; compute `allVisibleSelected` only when selecting; observe only what is needed (extract a child view so unrelated `AppData` publishes — `activeTab`, `coachMarkPaletteID` — don't re-run the body).
- [ ] (f) `MorphingCardGrid`: reduce overscan from `max(400, h/2)` to ~200; union `morphTargets` only while a layout toggle animates; add `.equatable()` support to `ColorMorphCard` (stable closure identity or `Equatable` on id+color+flags).
- [ ] (g) TDD the grid maths first: tests for `MorphingCardGrid.itemRange` and `columnCount` (currently untested) so (f) is safe.
- [ ] Acceptance: no hitches >8ms on a 500-color library at 120 Hz scroll. Commit per sub-step.

---

## Phase E — Naming, onboarding, Siri

### Task E1: Generated color/palette naming (#2)
**Files:** `Managers/PaletteGenerator.swift:25–60,262–290,300–320` (prompt + `GeneratedColorName`/`GeneratedNames` guides + `acceptedNames`), `Utilities/ColorVocabulary.swift:~120–175` (`describe`, `isPlausible`), `Utilities/HEXParser.swift` (ColorNamer `:42–130,457–482,492,538–655`), `Managers/PaletteNamer.swift:121–198`; Tests: `PaletteGeneratorTests`, `ColorVocabularyTests`, `ColorNamerTests`, `PaletteNamerTests`

**Root cause (confirmed from your screenshot):** names like "gentle, muted aquamarine", "steady, muted cerulean", "soft, mellow tangerine", "rich, deep amber" are the model echoing the *description format* we feed it. `modelNames` lists each color as `ColorVocabulary.describe(hex:)` = `"<lightness>, <chroma> <family>"` (e.g. "light, muted blue"), and the model mimics it: mood adjective + comma + color word. `isPlausible` only checks hue-ring distance, so these pass. Specific mismatches:
- `#57BBFF` (bright sky blue, vivid) → "aquamarine" (a green-cyan, hue ring ≤1 from blue so accepted) and "muted" (contradicts vivid).
- `#CBAA8E` (tan/beige, low chroma) → "tangerine" (vivid orange fruit; only hue is checked, never chroma/lightness of the noun).
- `#658BA8` → "steady, muted cerulean": fluff adjectives, and cerulean is a brighter blue.

**Fix:**
- [ ] Failing tests first (in `PaletteGeneratorTests.acceptedNames` and `ColorVocabularyTests`): reject any name containing a comma; reject names whose first word is a mood adjective (`gentle, steady, soft, rich, mellow, calm, bold, warm, cool`…) when it makes the name >1 word and the remainder is a bare hue/chroma word; reject names containing our own descriptor words (`muted`, `vivid`, `moderate`, `light`, `dark`) as standalone qualifiers; `isPlausible("tangerine", #CBAA8E)` false (low chroma); `isPlausible("aquamarine", #57BBFF)` false; `isPlausible("sky blue", #57BBFF)` true; `isPlausible("cerulean", #658BA8)` still acceptable or falls back; `"Terracotta"`/`"Sage"` style names for matching swatches true.
- [ ] Give each hue noun a chroma/lightness envelope in `ColorVocabulary` (e.g. tangerine/aquamarine/turquoise/coral/neon = C ≥ ~0.10; beige/tan/sand/taupe/khaki = C < ~0.07; navy/midnight = L < 0.4) and enforce it in `isPlausible`. Extend `hueWords` with a parallel `intensity` table rather than a new type.
- [ ] Stop the echo: change `describe(hex:)` output used in the prompt so it is not name-shaped — e.g. `"hex-free spec: lightness light, intensity muted, hue blue"` or lines like `1. L=light C=muted H=blue` — and add to the instructions: "Answer with the name only: 1–3 words, a noun like terracotta, sage, cobalt. No adjectives about mood, no commas, never repeat the words muted/vivid/light/dark." Add `@Guide(description: ...)` on `GeneratedColorName.name` with the same constraint (and examples).
- [ ] On rejection, the existing fallback (`ColorNamer.uniqueNames`) names it. Fix the data issues it exposed: mislabeled dictionary entries ("Vivid Tangerine" is salmon, "Antique Brass" pinkish, "Neon Yellow" lime, Shocking Pink ≈ Hot Magenta) via a data-integrity test (each entry's own RGB must satisfy `isPlausible` for its name); route `ColorNamer.name(forHex:)` (`:492`, used by pickers/photo extraction) through the same `entryFits` family filter; make `modifierFits` check the space the modifier was derived in.
- [ ] Palette title: `PaletteNamer.familyWord` should use the highest-chroma swatch, not the first chromatic one; keep `isPlausibleTitle`.
- [ ] Regression fixtures from the screenshot: `#57BBFF`, `#658BA8`, `#CBAA8E`, plus the "rich, deep amber" swatch (~brown/amber) — assert `acceptedNames` rejects the four bad names and that fallback names are single-noun and plausible.
- [ ] Verify on a device with Apple Intelligence (Simulator bypasses the model): generate 10 palettes with varied vibes and review the Colors tab.
- [ ] Commit.

### Task E2: Onboarding generation — haptics + faster ready (#9, #10)
**Files:** `Views/Onboarding/OnboardingInterimSteps.swift:131,136,238–283`, `OnboardingGeneration.swift:90–118`, `Managers/PaletteGenerator.swift:178–195`
- [ ] Haptic: in `GenerateInterimBody` add `.sensoryFeedback(.impact(weight: .light), trigger: flow.genColors.count)` (NOT in shared `GenerationSwatchRow`, to avoid double-firing on the Generate tab where `GenerationOrbView:143` already does it).
- [ ] Timing: reveal the first color immediately (no leading sleep); `revealDelay` 650 ms → ~380 ms; `PaletteGenerator.swift:187–189` per-color sleep 700 ms → ~380 ms and sleep *between* colors, not before the first.
- [ ] Don't block "ready" on model naming: race `await naming` against a ~600 ms timeout after the last color lands; fall back to `PaletteNamer`, and apply the AI name afterwards if it arrives.
- [ ] Trim the state animations stacking ~0.5 s after the last color (`:136` easeInOut 0.4, `:283` easeInOut 0.5, spring 0.45 in `GenerationSwatchRow:38`) to run concurrently (~0.3 s).
- [ ] Verify end-to-end on device: tap-to-ready under ~2 s for 4 colors. Commit.

### Task E3: Light-mode orb blends with island (#15)
**Files:** `Views/Onboarding/IslandMorph.swift:419–428,612–615,256–281,9`
- [ ] `IslandMorphStage.body`: `let dark = colorScheme == .dark && !fade` → `let dark = !fade`.
- [ ] `IslandGooCanvas`: remove the `colorScheme == .dark` condition on `fadeEnd` so the drop stays island-black until separation in both schemes.
- [ ] Rename `darkGlassReveal` → `glassReveal`; fix stale header comment (`:9`, "never black").
- [ ] Verify with held-pull screenshots (`-onboardingPullHold`, see memory *verify-morph-on-simulator*) on Duo + iPad in light and dark. Commit.

### Task E4: Camera preview shows yellow + diagonal line (#1)
**Files:** `Views/Onboarding/{OrbCameraPreview.swift:39–51,337–469,OnboardingCameraFlow.swift:57–62,OnboardingCameraStep.swift:68–80}`
- [ ] Repro and identify which branch renders: live `.camera`, `.photo(stillImage)` or the Simulator `OnboardingSampleImage` fallback (Simulator hard-returns `.unavailable`, so the sample image shows there). Check copy on screen ("Scan" = live; "Choose a photo" = sample/fallback). Ask which device/sim.
- [ ] If sample image: redraw `OnboardingSampleImage` as a neutral multi-colour scene. Note: its sun is pale-yellow — likely culprit when cropped/blurred by `InkFeather`.
- [ ] If live camera: test `layoutSubviews`/`applyPreviewAngle` (`:405–416`) and the `InkFeather` mask; verify on a real device in portrait and landscape.
- [ ] Commit with a note on the real cause.

### Task E5: Siri/App Intents (#9 "Siri AI implementation")
**Files:** `Intents/GeneratePaletteIntent.swift:34–41`, `PalettesShortcuts.swift:13–17`, `PaletteEntity.swift:46–65`, `App/AppData.swift`, `App/MyApp.swift`
- [ ] Simulator bypass: wrap the `SystemLanguageModel.default.availability` guard in `#if !targetEnvironment(simulator)` (same as `PaletteGenerator`/`GenerateView`).
- [ ] Surface the reason: `switch availability { case .unavailable(let r): throw AppError… }` with distinct text (AI off / model downloading / device ineligible).
- [ ] `vibe` parameter: add `requestValueDialog` ("What vibe should the palette have?") since a free-form String cannot be in the phrase.
- [ ] Call `PalettesShortcuts.updateAppShortcutParameters()` at launch and after palette/color changes (currently never called) so `Open <palette>` / `Get hex <color>` resolve.
- [ ] Make entity queries safe on cold launch: await `AppData` load before reading (`PaletteEntity.swift:46–65`).
- [ ] Update intent size handling for Auto from B1 (pass `nil` when unspecified).
- [ ] Verify via Shortcuts app on device: run Generate Palette with a vibe; run Open Palette. Commit.

---

### Task E6: Search palettes and colors from Shortcuts/Siri (new)
**Today:** `PalettesShortcuts` exposes only Generate Palette, Save Color, Open Palette and Get Hex. `FindPalettesIntent` exists (name-contains only) but has no App Shortcut, and there is **no Find Colors intent**; `CreatePaletteIntent` is also not surfaced. Hence "I can only generate a palette or create a color".
**Files:** create `Intents/FindColorsIntent.swift`, `Intents/SearchLibraryIntent.swift`; modify `Intents/FindPalettesIntent.swift`, `Intents/PalettesShortcuts.swift`, `Intents/PaletteEntity.swift` + `ColorEntity.swift` (queries), `Views/Main/SearchView.swift:12`, `App/AppData.swift` (add `@Published var pendingSearchTerm: String?` next to `pendingOpenPaletteID`, `:27`); Tests: `PalettesTests/AppDataIntentAPITests.swift`, `SearchMatchingTests.swift`
- [ ] Failing tests: a pure `LibrarySearch` helper (move the matching used by `SearchView.swift:39–46` and `SearchMatching.paletteMatchesQuery` into one place) — `colors(matching:in:)` matches name, hex with/without `#`, and hue words ("blue", "warm"); `palettes(matching:in:)` matches name, tags, and contained colour names/hexes. Assert `"#57bbff"`, `"57BBFF"`, `"ocean"`, `"blue"` cases. Intent-level: `AppData.shared` seeded with 2 palettes/3 colors; `FindPalettesIntent(searchTerm: "ocean").perform()` returns only matches; empty term returns all.
- [ ] `FindPalettesIntent`: use the shared helper (name + tags + colour names/hex, not just name) and `Summary("Find palettes matching \(\.$searchTerm)")`; keep returning `[PaletteEntity]` so Shortcuts can chain results.
- [ ] New `FindColorsIntent` (`Find Colors`, `searchTerm: String?`, returns `[ColorEntity]`) with the same behavior for colours (hex with/without `#`, name, hue family).
- [ ] New `SearchLibraryIntent: AppIntent, ShowInAppSearchResultsIntent` (`static let searchScopes: [StringSearchScope] = [.general]`, `openAppWhenRun = true`, `@Parameter var criteria: StringSearchCriteria`): sets `AppData.shared.pendingSearchTerm = criteria.term` and `activeTab = .search`; `SearchView` consumes it in `onChange`/`onAppear` (`searchText = term`, then clears it). Lets Siri/Spotlight "Search for ocean in Palettes".
- [ ] Make entity queries return palettes **and** colours consistently: `PaletteEntityQuery`/`ColorEntityQuery` `entities(matching:)` use the shared helper; `suggestedEntities()` returns recents (needed for the picker in Shortcuts).
- [ ] App Shortcuts (`PalettesShortcuts.swift`, stay under the 10-shortcut limit — currently 4): add `FindPalettesIntent` ("Find palettes in \(.applicationName)", "Search my palettes in \(.applicationName)", short title "Find Palettes", `magnifyingglass`), `FindColorsIntent` ("Find colors in \(.applicationName)", "Search my colors in \(.applicationName)", `magnifyingglass`), `SearchLibraryIntent` ("Search \(.applicationName)"), and `CreatePaletteIntent` ("Create a palette in \(.applicationName)"). Phrases must contain the app name; free-form `searchTerm` can't be in phrases, so Siri asks via `requestValueDialog` ("What should I search for?").
- [ ] Return a result view: `.result(value:dialog:view:)` using the existing `IntentSnippets` (swatch strip/colour chip) so Siri shows the matches, and spoken dialog "Found 3 palettes".
- [ ] Call `PalettesShortcuts.updateAppShortcutParameters()` (also listed in E5) and keep `EntityIndexer` in sync so Spotlight search finds palettes/colours too.
- [ ] Verify on device: Shortcuts app lists Find Palettes, Find Colors, Search Library, Create Palette, Generate Palette, Save Color, Open Palette, Get Hex; run "Find Colors" with "blue" → list result usable in a following "Get Details"; Siri: "Search my palettes in Palettes".
- [ ] Commit `Shortcuts: find palettes/colors and search the library`.

---

### Task E7: Siri SF Symbol in the onboarding Siri card (new)
**Today:** `OnboardingExtras.swift:293` uses `symbol: "waveform"`; `ExtrasCard` (`:~410–420`) renders `Image(systemName: symbol)` with `foregroundStyle(ink on tint)` on a tinted rounded square.
**Fix (no asset needed):** the new Siri mark is the SF Symbol `siri`.
**Files:** `Views/Onboarding/OnboardingExtras.swift`; Test: none (view-only; check by screenshot).
- [ ] `siriCard`: change `symbol: "waveform"` → `symbol: "siri"`.
- [ ] The symbol is multicolour and the card draws it with a single `foregroundStyle` over `tint.gradient`, which would flatten it. Add to `ExtrasCard` an optional `multicolor: Bool = false` (set true for Siri) that applies `.symbolRenderingMode(.multicolor)` and drops the tinted `background(tint.gradient…)`, using a neutral dark/white tile instead (`Color.black` in both schemes works best for the Siri glow; verify). Other cards are unchanged.
- [ ] Confirm `Image(systemName: "siri")` exists on the deployment target (iOS 17) and on iOS 26/27 (the card is already gated by `#available(iOS 26.0, *)`); add a fallback to `waveform` only if `UIImage(systemName: "siri") == nil`.
- [ ] `grep -rn '"waveform"' Palettes` and switch any other Siri-related uses (Settings, shortcut footer, replay) to `siri` for consistency.
- [ ] Verify light/dark and Dynamic Type XL on the onboarding extras screen. Commit `Onboarding: use the Siri symbol on the Siri card`.

---

## Verification (end-to-end)
- `xcodebuild test -project Palettes.xcodeproj -scheme Palettes -destination "platform=iOS Simulator,id=<throwaway>"` — all new suites green (PaletteBrief, SheetLayout, PaletteAddPanel, ColorNamer/Vocabulary/PaletteNamer, MorphingCardGrid).
- Manual matrix: iPhone portrait/landscape, iPad portrait/landscape, iPhone Duo cover / unfolded portrait / unfolded landscape × light/dark for: New Color, Edit Color, New Palette, Edit Palette, onboarding pull, Generate.
- Device-only checks (cannot be done on Simulator): camera preview, Siri/Shortcuts (generate, find, search) with Apple Intelligence, 120 Hz scrolling, haptics, tab-switch glitch.
- Update `plans/README.md` row 020 and run `graphify update .`.

## Self-review notes
- Coverage by bug: Siri SF Symbol in onboarding E7 · Shortcuts search/find palettes & colors E6 · camera preview E4 · color naming E1 · detail→Colors glitch D1 · Auto size B1 · remove modes A1 · vibe keyboard A2 · remove photo option A1 · onboarding haptics E2 · long wait to ready E2 · Siri E5 · harmony "–" C4 · taller swatch landscape C2 · Edit Palette landscape C5 · Colors lag/120Hz A4+D2 · Settings everywhere A3 · remove Added Colors + subtext C3 · onboarding orb light mode E3 · Duo/iPad split layout C3 · Library cut off on Duo cover C3 · drop "Palette" from Size A1 · iPad/Duo use iPhone landscape sheet C1+C2.
- Cross-references in task headings to "#n" are loose; use the bug names above.
