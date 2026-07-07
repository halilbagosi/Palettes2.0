# New Color Page Redesign — Design

**Date:** 2026-07-07
**Status:** Approved (user accepted conflict caveat with parallel session on
NewColorView.swift)

## Goal

Collapse the redundant HEX/RGB/Scan structure of the New Color page into two
modes with one create pipeline, deduplicate repeated UI blocks, and restyle
with Liquid Glass.

## Changes

### 1. `Views/Components/InteractiveColorPicker.swift` (modify)

- Delete `ColorInputMode` and the `mode` property; the picker always shows the
  color wheel plus BOTH the editable HEX row and the editable RGB row (they are
  live-synced views of the same color).
- Delete the read-only `rgbString` line (redundant with the editable RGB row).
- Glass restyle: name/HEX/RGB fields use `.glassEffect(.regular, in:
  .rect(cornerRadius:))` instead of `.ultraThinMaterial` + stroke.
- Modernize `onChange` to two-parameter form.

### 2. `Views/Components/AdjustmentSlider.swift` (new)

`AdjustmentSlider(title:valueLabel:leftLabel:rightLabel:value:)` — the
title+value header, slider, and left/right caption row currently copy-pasted
three times in scan mode.

### 3. `Views/Color/NewColorView.swift` (rewrite)

- `enum InputMode { pick, scan }` with a glass segmented control ("Pick" /
  "Scan") replacing the HEX/RGB/Scan menu picker.
- Pick mode: single `InteractiveColorPicker` call (duplicate
  `hexInputContent`/`rgbInputContent` deleted).
- Scan mode: photo card + Camera/Library buttons (glass), then preview,
  3× `AdjustmentSlider` (Temperature/Saturation/Brightness), and
  `EditableValuesView`, as today.
- One `colorName` state replaces `hexColorName`/`scanColorName`; one shared
  name field position per mode retained but bound to the same state.
- One `canCreate` and one `createColor()`: resolves (hex, color) from the
  active mode (pick → `currentHEX`; scan → `adjustedHex`), validates name,
  appends. Single Create toolbar button.
- Duplicate hex: toast "This color already exists as '<name>'" and the sheet
  stays open (today it silently discards and dismisses).
- Auto-name behavior preserved in both modes (ColorNamer / existing-color
  lookup).
- Modernize `onChange`; glass restyle of remaining fields/buttons.

## Verification

Build succeeds; simulator screenshots of Pick and Scan modes; create a color
via Pick mode and confirm it appears (or duplicate toast shows).
