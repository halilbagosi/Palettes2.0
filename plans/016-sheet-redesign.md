# Sheet Redesign: Settings, New Palette, New Color (016)

**Goal:** The creation sheets and Settings look like the rest of the app and
follow the order people actually work in.

**Status:** Implemented on `feature/sheet-redesign`. Built without Xcode, so
`xcodebuild` and on-device checks are still pending (see Verification).

## What was wrong

**New Palette**
- The name came first and was required, before there was anything to name.
  Create stayed disabled until the user typed one.
- The strip preview, an "Added Colors" row list and the whole input surface
  were stacked in one scroll. Each added color pushed the input further down,
  so the add button moved away after every tap.
- Scanning a photo silently **replaced** every color already in the draft.
- The "Already in this palette" toast was hidden behind the sheet, because
  the sheet had no toast overlay.
- It looked nothing like the palette it produces, or like the Generate
  result, which shapes a palette in the same way.

**New Color**
- A plain sheet, while the color's own page (`ColorDetailView`) and its edit
  sheet are washed in the color with a large color window.
- The "Color Wheel" was the system color well scaled up to 1.5×: a small
  button that opens another sheet, not a wheel.
- There were two previews in Scan (the photo, then a separate swatch), and the
  Camera / Library buttons sat apart from the photo they fill.
- Every color change overwrote the name, including a name the user had typed.
- A pasted `#ff5d00` was rejected, and the field turned red while the user
  was still typing.

**Settings**
- A stock form with no connection to the app. Replay Onboarding was filed
  under About, and Delete All Data sat right next to Export.

## What changed

### Shared pieces (`Views/Components/SheetComponents.swift`, `GradientSlider.swift`, `PaletteBandCard.swift`)
- `ColorWashBackground` and `SwatchHero`: the wash and the 24 pt color window
  from `ColorDetailView`, reused as-is.
- `PaletteStrip`: the detail page's hero strip, with a dashed outline when empty.
- `PaletteBandCard`: the Generate result's band card (32 pt corners, a band
  per color, legible ink, a remove button). Tap a band to edit it; its context
  menu adds Move Up/Down and Remove.
- `HSBSlidersCard` and `GradientSlider`: hue, saturation and brightness
  sliders whose tracks show the colors they select. The thumb shows the
  current color. A row on the card opens the system picker's eyedropper and
  spectrum.
- `ColorNameField` and `SheetSectionHeader`: the shared name card and the
  section caption style.

### New Palette
1. **Name**: the big rounded title from the Generate result. Its placeholder
   is a `PaletteNamer.descriptiveName` suggestion, and a blank name takes that
   suggestion. Create is enabled once there are two colors.
2. **Card**: before the first color, a dashed card offers the three ways to
   start (Pick / Library / Photo). Once there are colors, it becomes the band
   card.
3. **Add Colors** opens `AddColorsSheet` at the medium detent, over the card.
   The sheet stays open for several adds and has a live strip on top. A photo
   scan into a non-empty palette asks: **Add N Colors**, or **Replace Current
   Colors**.
4. The draft is a `[PaletteColor]` rather than three parallel arrays, which
   fits plan 003 and the alignment invariant in CLAUDE.md.

### Add Color (from Edit Palette)
- Now the same `AddColorsSheet`: the strip shows each color arrive, and Done
  replaces ×. It no longer shows a toast after every add.

### Shared input (`ColorInputView`, `InteractiveColorPicker`)
- **Pick**: name card, then the HSB card, then a Values card (HEX and RGB).
  The HEX field drops anything that isn't a hex digit, so pasting `#ff5d00`
  works. While a code is incomplete, a quiet hint replaces the red error.
- **Scan**: one photo surface. When empty, it holds Camera and Photos buttons.
  With a photo, it has a replace menu and "Tap to pick a color". Below it come
  the name, the Fine-tune sliders and the values.
- **Library**: newest colors first, with a search field once there are more
  than 6.
- The add button is full width. A color already in the palette reads
  **Already Added**, in place of a toast after the tap.
- The auto-name follows the color only until the user types a name of their own.
- Pick starts on a random pleasant color rather than pure red.
- `ColorInputController.previewHex` lets a host draw its own preview.

### New Color
- The sheet now looks like the page the color is about to get: a `SwatchHero`
  over a `ColorWashBackground`, both updating live as the color changes. Pick
  and Scan sit below.
- The sheet hosts its own toast overlay.

### Edit Color
- The scaled color well is replaced by the same `HSBSlidersCard`. The relative
  Saturation and Brightness sliders are removed, since they duplicated the
  card. Temperature stays, because the card can't change warmth directly.

### Settings
- **Header**: a tile in the colors of the user's latest palette (a spectrum
  until there is one), "Palettes", the palette and color counts, and the
  version.
- **Rows**: tinted icon tiles, as in iOS Settings, with subtitles and an
  outbound arrow on links that leave the app.
- **Sections**: Sync (On or Off status, plus Open Settings when signed out),
  Library (Export, disabled when the library is empty), Help (Replay
  Onboarding, Contact Support), Legal, and then Delete All Data on its own at
  the bottom. Its confirmation states what will be deleted, with counts. The
  Debug section is unchanged.

## Verification (pending an Xcode machine)
- [ ] Build: zero new warnings.
- [ ] New Palette:
  - Start from each of the three tiles.
  - Add from the Library, then Pick (check the Already Added state), then a
    photo scan into a non-empty draft (check both dialog choices).
  - Edit a band, remove a band, and use Move Up/Down.
  - Create with a blank name: the suggestion is used.
  - Preselected color: from the Colors tab and from a color's detail page.
- [ ] New Color:
  - The wash and the hero follow the HSB sliders and the HEX and RGB fields.
  - Paste `#ff5d00` into the HEX field.
  - Scan, then tap to pick an exact spot; the replace menu works.
  - Duplicate dialogs still appear.
- [ ] Edit Color: the HSB card and Temperature stay in sync with HEX and RGB.
- [ ] Settings:
  - Signed-in and signed-out iCloud states.
  - Export, Replay Onboarding, Delete All Data.
  - Dynamic Type at the largest sizes.
- [ ] VoiceOver:
  - Slider adjustable actions.
  - Band card: the default action is edit; Remove is a named action.
- [ ] iOS 17 (material fallbacks) and iOS 26 (Liquid Glass).

## Follow-ups (not done here)
- `GenerationResultView` could adopt `PaletteBandCard`. It keeps its own copy
  for now because of its staggered reveal.
- `ColorDetailView` and `ColorEditView` could use `ColorWashBackground` and
  `SwatchHero` in place of their inline copies.
- `PaletteEditSheet` is still a plain inset list. It could get the band card
  too, which would make edit and create the same surface.
