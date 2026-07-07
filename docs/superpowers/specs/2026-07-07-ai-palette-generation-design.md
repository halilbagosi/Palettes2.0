# AI Palette Generation (Generate Tab) — Design

**Date:** 2026-07-07
**Status:** Approved

## Goal

Enable the Generate tab. From at least one input color (and optionally more colors, a
"vibe" description, and/or a photo), generate a named palette of complementary colors
on-device using Apple's Foundation Models framework, preview it in a sheet, and save it
to the user's palettes.

## Context

- Deployment target is iOS 27, so Foundation Models (iOS 26+) is always linkable.
  All `#available(iOS 18/26)` branches in `PaletteTabView` are dead code, as is the
  `sysctlbyname` device-model check.
- `GenerateView` UI already exists (size slider, color multi-select, vibe field,
  camera/photo picker) but the send button is a placeholder and the tab is absent from
  the active TabView branch.

## Components

### 1. PaletteTabView (modify)

- Collapse to a single `TabView` (remove dead branches and device sniffing).
- Add `Tab("Generate", systemImage: "sparkles", value: .generate) { GenerateView() }`
  unconditionally.

### 2. Managers/PaletteGenerator.swift (new)

- `@Generable struct GeneratedPalette`: `name` (short palette name) +
  `colors: [GeneratedColor]`; `@Generable struct GeneratedColor`: `hex`
  (pattern-guided 6-digit RGB) + `name` (short color name).
- `static func generate(baseColors: [(hex: String, name: String)], size: Int,
  vibe: String?) async throws -> PaletteViewModel`
  - Guards `SystemLanguageModel.default.availability == .available`,
    else throws `AppError.aiUnavailable`.
  - `LanguageModelSession` with color-theory designer instructions; prompt lists base
    colors, requested size, optional vibe. Base colors are included in the result.
  - Requested size is enforced via prompt + post-trim (array count can't be guided
    dynamically).
  - Each hex validated through `Color(hex:)`; invalid entries dropped; < 2 valid →
    `AppError.generationFailed`.
  - Returns a `PaletteViewModel` (colors, hexCodes, colorNames populated).

### 3. AppError (modify)

- New cases: `aiUnavailable`, `generationFailed` with user-facing descriptions.

### 4. GenerateView (modify)

- Availability gate: `switch SystemLanguageModel.default.availability` — unavailable
  reasons render a styled empty state (device not eligible / Apple Intelligence off /
  model downloading) instead of the controls.
- Send button enabled when ≥ 1 input exists: selected color(s), non-empty vibe, or a
  photo. Photo → `ImageColorExtractor.extractColors(count: 4)` results join the base
  colors; thumbnail chip with remove (✕) shown in the input row.
- Generating state: inputs disabled, send button shows progress with the existing
  glow-gradient styling.
- Errors surface via `ToastManager`.
- Success presents `GeneratedPaletteSheet`.

### 5. Views/Components/GeneratedPaletteSheet.swift (new)

- Shows palette name + swatch rows (color, name, hex) styled like existing cells.
- **Regenerate**: re-runs generation with the same inputs, updates in place.
- **Save**: appends to `appData.palettes`, `ToastManager` confirmation, dismisses.

## Error handling

- Model unavailable → empty state (not an error toast).
- Generation/guardrail/validation failures → toast with `AppError` description;
  user can retry.

## Testing / verification

- `xcodebuild` for iOS Simulator must succeed with no errors.
- Manual run: generate from 1 color, from vibe only, from photo; save; regenerate;
  availability empty state.
- No unit test target exists; none added (per approval).
