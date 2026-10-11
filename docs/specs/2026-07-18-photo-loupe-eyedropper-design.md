# Photo Loupe Eyedropper — Design

**Date:** 2026-07-18
**Status:** Approved, pending implementation plan
**Branch:** `feature/photo-loupe-eyedropper` (feature → dev → staging → main)

## Problem

When creating a single color from a photo (the **Scan** source, `.dominant`
extraction mode in `ColorInputView`), the app auto-picks one dominant color
from the whole image. If the photo contains several colors and the user wants a
different one, there is no way to choose it — the displayed photo is a static
preview. Users need to point at a specific spot in the photo and sample that
color.

## Scope

- Applies **only** to the single-color photo flow: `ScanExtraction.dominant`
  in `ColorInputView`.
- The multi-color `.palette` extraction mode is **unchanged**.
- Works for both Library-picked and Camera-captured photos (both land in
  `selectedImage`).
- Out of scope: changing the clustering/auto-extract algorithm, the palette
  extraction flow, or the Pick/Library sources.

## User flow

1. User picks or takes a photo. Auto-extract runs exactly as today: it picks
   the dominant color and populates the swatch, sliders, and name. The photo
   displays **aspect-fill** (the current cropped look).
2. The photo carries a discoverability affordance (a subtle hint that it can be
   dragged to pick a color).
3. On press, the photo animates from fill → **fit** (whole image visible,
   letterboxed) so every region is reachable, and a **magnifier loupe** appears
   near the finger: a zoomed circular view of the pixels under a crosshair with
   a live swatch of the sampled color.
4. As the user drags, the sampled color updates **live** — the loupe swatch,
   the `adjustedColor` preview, and the base RGB feeding the sliders all track
   the crosshair continuously. Sampling averages a **small region** around the
   crosshair (stable against JPEG noise / grain), not a single raw pixel.
5. On release, the photo animates back to fill, the loupe disappears, and the
   color name (`scanName`) is recomputed for the final sampled color. The name
   lookup is deferred to release — it does **not** run on every drag frame.
6. Each new sample resets the three adjustment sliders
   (temperature/saturation/brightness) to neutral (0.5), exactly like the
   current auto-extract does, so tweaking always starts from the sampled base.

## Requirements

- **Sliders must keep working on the sampled color.** The loupe writes the
  sampled RGB into the same `baseR/baseG/baseB` state the sliders read from, and
  `adjustedRGB` recomputes from there. After sampling a spot, the
  temperature/saturation/brightness sliders adjust *from* that sampled color —
  identical to how they behave after auto-extract. This convergence on shared
  state is a hard requirement, not an incidental.
- Auto-extract on photo load is preserved so there is always an immediate
  result before the user touches the photo.
- Live sampling during drag; name recompute only on drag-end.

## Architecture

Three focused, independently understandable pieces:

### 1. Pixel-sampling utility — `ImageColorExtractor`

Add a synchronous function:

```
sampleColor(from image: UIImage, at normalizedPoint: CGPoint, radius: Int) -> (r: Double, g: Double, b: Double)
```

- `normalizedPoint` is in 0–1 image space (0,0 = top-left, 1,1 = bottom-right).
- Averages a small neighborhood (`radius` pixels) around the point.
- Reuses the existing `CGContext` pixel-reading approach (`getPixels`-style),
  but reads one small region rather than clustering the whole image.
- Pure and synchronous — no SwiftUI, no `AppData`. Unit-testable: known image +
  known point → known color.
- Clamps out-of-bounds coordinates to the nearest valid pixel.

### 2. Reusable `PhotoLoupeView` (new SwiftUI view)

Self-contained view that:

- Takes a `UIImage` and reports sampling events out via a callback (e.g.
  `onSample(normalizedPoint)` during drag and an `onSampleEnd` on release, or a
  callback carrying the sampled color — exact shape decided in the plan).
- Renders the image and animates between **fill** (at rest) and **fit** (while
  dragging).
- Handles the drag gesture and the **display → image coordinate mapping**,
  correcting for aspect ratio and letterbox bars.
- Draws the magnifier loupe (zoomed pixels + crosshair + swatch), flipping the
  loupe below the finger when near the top edge so it is not clipped.
- Owns none of the scan/adjustment/naming state — it only reports *where* the
  user is sampling. This isolates the coordinate math and makes the view
  previewable on its own.

### 3. Wiring in `ColorInputView`

- `photoArea` swaps its static `Image` for `PhotoLoupeView` when in `.dominant`
  mode with a `selectedImage` present.
- The loupe's sampling callback:
  - calls `ImageColorExtractor.sampleColor(...)`,
  - sets `baseR/baseG/baseB`,
  - resets `temperatureValue/saturationValue/brightnessValue` to 0.5,
  - sets `hasExtractedColor = true`,
  - on drag-end, recomputes `scanName` via the existing `autoName(forRawHex:)`.
- This mirrors exactly what `extract(from:)` already does for auto-extract, so
  both the auto path and the loupe path converge on identical downstream state.

**Isolation summary:** `PhotoLoupeView` knows nothing about sliders, naming, or
`AppData`. `ImageColorExtractor.sampleColor` knows nothing about SwiftUI.
`ColorInputView` orchestrates the two.

## Edge cases

- **Coordinate mapping** (main correctness risk): fit-mode letterbox math must
  map the finger position in the view to the correct image pixel, correcting
  for aspect ratio and bars. Covered by unit tests across a few aspect ratios.
- **Letterbox bars / out of bounds**: if the finger is over a bar (outside the
  image), clamp to the nearest edge pixel — never sample a bar or crash.
- **Loupe near screen edges**: the magnifier offsets above the finger by
  default and flips below near the top so it is not clipped.
- **Slider reset**: every new sample resets the three sliders to 0.5,
  consistent with auto-extract.
- **Name-lookup cost**: `scanName` recompute (which scans `appData.colors` +
  `ColorNamer`) runs on drag-end only, not per drag frame.

## Testing

- Unit tests for `ImageColorExtractor.sampleColor`: known image → known color,
  including out-of-bounds clamping.
- Unit tests for the display → image coordinate-mapping function across a few
  aspect ratios (portrait/landscape/square) and letterbox cases.
- SwiftUI preview for `PhotoLoupeView` for manual/visual verification.
- Existing auto-extract path (`extract(from:)`, `extractDominantRGB`) remains
  intact and untouched in behavior.

## Compatibility notes

- Deployment target is iOS 17.0. Any iOS 26-only APIs must be gated behind
  `@available(iOS 26.0, *)` via the `Palettes/Compatibility/` shims. The loupe
  should be built with standard SwiftUI gestures/rendering available on iOS 17.
- Preserve the `PaletteViewModel` parallel-array alignment invariant if any
  touched code borders it (not expected for this feature).
