# Sheet Redesign: Settings, New Palette, New Color (016)

**Goal:** The creation sheets work the way iOS sheets do, so they need no
explaining, and they look like the rest of the app.

**Status:** Revision 2 is implemented on `feature/sheet-redesign`. It was built
without Xcode, so `xcodebuild` and the on-device checks below are still
pending.

## Revision 2: what was still wrong with revision 1

Revision 1 restyled the sheets but kept their structure.

- **New Palette** opened an "Add Colors" sheet on top of itself. The HIG says
  to avoid stacking modals.
  - Its empty-state tiles and the "Add Colors" button led to the same place.
  - Editing a color opened yet another sheet.
- **New Color** was one long scroll of glass cards, with Pick and Scan as
  separate modes.
  - The preview scrolled away while values were being edited.
  - The number pad had no way to dismiss it.
  - Scan used different sliders from Pick.
- **New Color, Edit Color and adding a color to a palette** were three
  different editors.

## Principles applied (Apple HIG, design-engineering review)

- **Navigation:** one sheet, with navigation inside it by push, never a sheet
  on a sheet. Lists use the standard grouped style, and pushed rows show a
  chevron.
- **Feedback:** the thing being made stays in view. The swatch and name, or
  the palette strip and name, are pinned above the scrolling controls.
- **Consistency:** one editor everywhere a color is made or changed.
- **Standard controls and gestures:**
  - Swipe to delete, touch and hold to reorder.
  - `.searchable` for search, and `ContentUnavailableView` for empty and
    no-result states.
  - The system color picker row for the spectrum and eyedropper.
- **Toolbar buttons:** the confirm action sits at top trailing and is disabled
  until it's valid. On iOS 26 the buttons are the glass ✕ and ✓; earlier
  systems show "Cancel" and a bold "Add"/"Save"/"Create" (see
  `Compatibility/SheetToolbarCompat.swift`).
- **Protect work:** an unsaved palette can't be swiped away, and Cancel asks
  "Discard this palette?".
- **Validate before the tap:** "Already saved as …" and "Already in this
  palette" appear under the name before the user taps Add, not as an error
  afterwards.
- **Keyboard:**
  - A Done button above the keyboard.
  - The header shrinks while a value field is being edited.
  - A half-typed value reverts when the field loses focus.
  - Pasting `#ff5d00` into the HEX field works.

## What changed

### `ColorComposer`, the one color editor
- **Pinned header:**
  - The live swatch, with its hex. Long-press it to copy the hex.
  - The name field.
  - A notice line, when there's something to flag.
  - **Sample a Photo** / **Take Photo**, which open the photo sampler seeded
    with the photo's main color. Tap the exact spot, then Use.
- **Form below it:**
  - **Adjust:** hue, saturation and brightness gradient sliders, plus a
    "Spectrum & Eyedropper" row using the system `ColorPicker`.
  - **Values:** HEX and RGB.
- **Background:** the color-wash backdrop from the color detail page.
- **Naming:** for a new color, the name follows the color until the user
  types their own.
- **Used by:** New Color, Edit Color (every call site, API unchanged), a new
  color added to a palette, and editing a draft palette color.

### New Palette
- **Pinned header:** the palette strip, then the name field. Its placeholder
  is the `PaletteNamer` suggestion, which is used if the name is left blank.
- **Colors** (`N Colors`): a list. Tap a color to push the editor (changes
  apply live), swipe to remove, touch and hold to reorder.
- **Add Colors / Add More:**
  - **New Color** pushes the editor, with Add.
  - **From Your Library** pushes a searchable multi-select list. Colors
    already in the palette show as checked.
  - **From a Photo** is a menu: Choose Photo or Take Photo. It pulls six
    colors. If the palette already has colors, it asks: Add, or Replace.
- The footer explains the two-color minimum. Create stays disabled until it's
  met.

### Add Colors (from Edit Palette)
- The same pages: the library multi-select, with a **New Color** row at the
  top. Either add closes the sheet.

### Settings
- A **plan tag** next to the app name: a gray **FREE**, or a **PREMIUM** tag
  with a crown on a warm gradient.
- `SubscriptionStatus` reads StoreKit 2's `Transaction.currentEntitlements`
  and listens to `Transaction.updates`.
- `productIDs` is empty until the subscription exists in App Store Connect
  (TODO(owner)), so everyone shows as Free.
- Debug builds get a **Plan** override (Automatic / Free / Premium) in the
  Debug section.

### Removed
- `ColorInputView`, `InteractiveColorPicker`, `EditableValuesView`,
  `PaletteBandCard`, `HSBSlidersCard`, `SwatchHero`, `ColorNameField`,
  `SheetSectionHeader`.
- Edit Color's Temperature slider. The sliders, the system spectrum and photo
  sampling cover the same ground.

## Verification (pending an Xcode machine)
- [ ] Build: zero new warnings.
- [ ] New Color:
  - The sliders, HEX, RGB and the Spectrum row stay in sync.
  - The header shrinks while editing values, and Done dismisses the number
    pad.
  - Pasting `#ff5d00` into HEX works.
  - Sample a Photo and Take Photo each reach the sampler and set the color.
  - A saved hex shows the notice, and Add then offers to rename it.
- [ ] Edit Color, from:
  - the Colors tab;
  - Color detail;
  - Palette detail (the overwrite prompt);
  - Edit Palette;
  - the Generate result.
- [ ] New Palette:
  - Each add path works.
  - Reorder by touching and holding.
  - Swipe to delete.
  - Edit a draft color: its hex updates.
  - Photo into a non-empty palette: try both choices.
  - Swipe down with changes: it's blocked. Cancel asks first.
  - Create with a blank name: the suggestion is used.
  - Preselected color.
- [ ] Add Colors from Edit Palette: the library multi-select, and New Color.
- [ ] Settings: the Free tag, and Premium via the Debug override; the plan tag
  is read out by VoiceOver.
- [ ] iOS 17 (text buttons, material) and iOS 26 (glass ✕/✓); Dynamic Type
  at the largest sizes; VoiceOver on the sliders (adjustable).

## Follow-ups
- `PaletteEditSheet` could reuse the New Palette list, which would make edit
  and create the same surface.
- `ColorDetailView` could use `ColorWashBackground` in place of its inline
  copy.
- The paywall and purchase flow for Premium.
