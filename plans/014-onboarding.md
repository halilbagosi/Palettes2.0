# Onboarding Implementation Plan (014)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A first-launch onboarding that teaches the app by doing: pull down, a liquid-glass orb detaches from the Dynamic Island, the user scans a color from the camera, adjusts it, generates a palette, and lands in palette detail with a hint to long-press a color. Optional closing cards show export and Siri.

**Architecture:** One `OnboardingView` presented full-screen over `PaletteTabView` when `@AppStorage("didCompleteOnboarding")` is false. It is a small state machine (`OnboardingStep`) that owns a single `OnboardingModel` (permission state, scanned color, chosen adjustments). It reuses the existing color-input and generation UI and does not duplicate them. Saved data goes through `AppData` only, as with the rest of the app. The final handoff creates the palette via `AppData`, dismisses onboarding, and selects the new palette so `PaletteTabView` pushes `PaletteDetailView`.

**Tech Stack:** SwiftUI, AVFoundation (live preview), existing `Compatibility/` glass shims. iOS 26 Liquid Glass is gated behind `@available(iOS 26.0, *)`; iOS 17+ gets a material-based orb.

## Flow

| # | Step | What the user sees | Reuse |
|---|---|---|---|
| 0 | `.pull` | "Pull down to begin" prompt; drag gesture. | new |
| 1 | `.orb` | Orb detaches from the Dynamic Island (black → clear), settles at center. Caption: "Explore the colors around you." | `GenerationOrbView` look, `LiquidGradientView` |
| 2 | `.camera` | Permission pre-prompt, then circular live preview inside the orb with faded edges. "Scan" button below. "Use a photo instead" link. | `CameraPicker` (reference only), new `OrbCameraPreview` |
| 3 | `.adjust` | Frame freezes, ripple, sampled color drops out and becomes the selected color. Tap the frozen frame to re-sample. Sliders (brightness, saturation only) and "Generate palette" below. | `PhotoColorPickerView`, `ColorInputView`, `AdjustmentSlider`, `ColorAdjustment` |
| 4 | `.generate` | Same screen: generate UI fades in; orb shows the chosen color; options appear. Palette blooms from the orb. Generated name text uses the badge gradient. | `GenerationExperienceView`, `GenerationOrbView`, `GeneratedGradient`, `PaletteGenerator`, `PaletteNamer` |
| 5 | `.detail` | Onboarding dismisses into `PaletteDetailView`; coach mark "Long press a color for options, or tag it." Dismisses on first long press. | `PaletteDetailView`, `RoleBadge`, `RolePickerSheet` |
| 6 | `.extras` (optional, skippable) | Cards: Share (rendered image), Siri/Spotlight, and a reserved widget slot (hidden until the widget ships). | `PaletteImageRenderer`, `ExportPaletteSheet`, `Intents/*` |

## Global Constraints

- **Deployment target:** iOS 17.0. Glass effects and Apple Intelligence generation stay behind `@available(iOS 26.0, *)` via `Palettes/Compatibility/`. Extend the shims; do not raise the target.
- **New files:** auto-included by synchronized groups. Never edit `Palettes.xcodeproj/project.pbxproj`.
- **Persistence:** read/write palettes only through `AppData`. Onboarding state is `@AppStorage("didCompleteOnboarding")` (a per-device flag; fine for v1).
- **Parallel arrays:** `PaletteViewModel`'s `colors`, `hexCodes`, `colorNames`, `colorRoles` stay index-aligned (CLAUDE.md caveat).
- **Camera permission:** add `NSCameraUsageDescription` (already present in `Palettes/AppInfo.plist`, used by `CameraPicker`; nothing to add). Ask only at step 2, after the orb settles. A denial or restriction routes to the photo/sample fallback, never a dead end.
- **Simulator:** no camera. `OrbCameraPreview` must fall back to a bundled sample image under `#if targetEnvironment(simulator)` or when no capture device exists.
- **Accessibility:** every step has Skip. Reduce Motion replaces the detach/bloom with a cross-fade. VoiceOver labels on the orb, Scan and Skip. Dynamic Type must not clip captions.
- **Haptics:** one light impact per step change, one medium on Scan.
- **Do not touch:** `ColorsView.swift`, `MorphingCardGrid.swift`, and the other files with uncommitted work (`ColorMorphCard`, `PaletteMorphCard`, `SelectionCheckmark`, `PaletteView`) until that work is committed. Plan 013 Task 7 owns `GenerateView.swift`.
- **Build:** `xcodebuild build -project Palettes.xcodeproj -scheme Palettes -destination "id=<UDID>" -quiet`, zero new warnings. Use a throwaway simulator for long runs.
- **Branch:** `feature/onboarding` from `dev`. Commits end with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## File Map

| File | Change | Responsibility |
|---|---|---|
| `Palettes/Views/Onboarding/OnboardingView.swift` | Create | Step state machine, transitions, Skip |
| `Palettes/Views/Onboarding/OnboardingModel.swift` | Create | Permission state, scanned color, adjustments |
| `Palettes/Views/Onboarding/OnboardingOrb.swift` | Create | Detach-from-island animation, black → clear |
| `Palettes/Views/Onboarding/OrbCameraPreview.swift` | Create | `AVCaptureSession` preview, circular mask with faded edge, still capture, simulator fallback |
| `Palettes/Views/Onboarding/OnboardingCoachMark.swift` | Create | Auto-dismissing hint overlay for step 5 |
| `Palettes/Views/Onboarding/OnboardingExtrasView.swift` | Create | Share and Siri cards, reserved widget slot |
| `Palettes/Compatibility/LiquidGlassCompat.swift` | Modify | Add an orb-glass shim if the existing ones don't cover it |
| `Palettes/App/MyApp.swift` | Modify | Present onboarding when the flag is false |
| `Palettes/Views/Main/PaletteTabView.swift` | Modify | Accept a palette to push after onboarding |
| `PalettesTests/OnboardingModelTests.swift` | Create | Step progression and fallback logic |

## Tasks

### Task 1: Onboarding shell and gating
- [x] Create `OnboardingStep` enum and `OnboardingModel` (current step, `advance()`, `skip()`, permission status, scanned RGB).
- [x] Create `OnboardingView` with placeholder content per step and a Skip button.
- [x] Gate (in `PaletteTabView`, not `MyApp.swift`): `fullScreenCover` over `PaletteTabView` on `!didCompleteOnboarding`; Skip and finish both set the flag.
- [x] Add a user-facing "Replay onboarding" (Settings > About; not debug-only) row to `SettingsView` (also useful as a user-facing feature later).
- [x] Tests: `advance()` order, `skip()` ends the flow, flag is set on finish.

### Task 2: Pull and orb detach (steps 0–1)
- [x] Drag-down gesture with rubber-band; at threshold, the orb separates from the top center and travels to the screen center.
- [x] Orb fill animates black → clear. iOS 26: glass effect; iOS 17–25: `.ultraThinMaterial` with a specular edge.
- [x] Reduce Motion: cross-fade the orb in at center.
- [x] Verify on the iPhone 17 Pro simulator (Dynamic Island position).
- [ ] Check a notch-less device size for a sensible fallback (not yet verified).

### Task 3: Camera in the orb (step 2)
- [x] `OrbCameraPreview`: `AVCaptureVideoPreviewLayer` in a `UIViewRepresentable`, masked to a circle with a radial gradient mask so edges fade into the glass.
- [x] Permission pre-prompt line, then `AVCaptureDevice.requestAccess`. Handle `.denied`/`.restricted` by showing "Use a photo instead" (PhotosPicker) and the sample image.
- [x] Scan button captures a still (`AVCapturePhotoOutput`), freezes it in the orb, ripple, medium haptic.
- [x] Stop the session when leaving the step or backgrounding.

### Task 4: Sample, adjust, generate (steps 3–4)
- [x] Sample the center color of the still using `ImageColorExtractor`. Animate it dropping out of the orb into the selected color.
- [x] Tap on the frozen frame re-samples (use `PhotoLoupeGeometry` normalization as `PhotoColorPickerView` does).
- [x] Show brightness and saturation sliders via `AdjustmentSlider` + `ColorAdjustment`, plus a "Generate palette" button.
- [x] On tap, fade in the generation UI on the same screen with the color preselected inside the orb (`GenerationExperienceView`). Palette blooms from the orb.
- [x] Generated name: fill with `GeneratedGradient` (iOS 26 AI path); non-AI path shows a normal name.
- [x] Create the palette through `AppData`; keep `colors`/`hexCodes`/`colorNames` aligned.

### Task 5: Detail handoff and coach mark (step 5)
- [x] Dismiss onboarding and have `PaletteTabView` push `PaletteDetailView` for the new palette.
- [x] `OnboardingCoachMark`: non-modal overlay "Long press a color for options, or tag it." Dismiss on first long press or a tap on the hint; once shown, never again.

### Task 6: Extras cards (step 6, optional)
- [x] Share card: render with `PaletteImageRenderer`, button opens `ExportPaletteSheet`.
- [x] Siri card: "Ask Siri: generate a palette", plus a line that palettes appear in Spotlight (`EntityIndexer`).
- [x] Reserved widget slot: a `static let showsWidgetCard = false` constant; flip it when the widget ships.
- [x] iCloud line only if v1 ships with CloudKit enabled (see launch-data-model decision).

### Task 7: Polish and verification
- [ ] Accessibility pass (VoiceOver order, Dynamic Type, Reduce Motion).
- [ ] Run on iPhone 17 Pro simulator through all steps using the sample image; capture screenshots per step.
- [ ] Full test run; zero new warnings.
- [ ] Update `plans/README.md` status.

## Verification

1. Fresh install (delete the app): onboarding appears; completing it lands in palette detail with the new palette and the coach mark.
2. Relaunch: onboarding does not reappear. Settings → Replay shows it again.
3. Deny camera permission: flow continues through the photo/sample fallback.
4. Reduce Motion on: no detach or bloom, only fades.
5. iOS 17 simulator (if available): material orb renders; no iOS 26 API is called.
6. `xcodebuild test` passes, including `OnboardingModelTests`.

## Implementation notes (Tasks 1-2)

- The cover is presented from `PaletteTabView` (after the environment objects, so reused views get `AppData`), not `MyApp`.
- In-cover steps end at `.generate`; the detail coach mark and extras cards run after the cover dismisses, with their own `@AppStorage` keys.
- `OnboardingModel` has no persistence: it reports `OnboardingFinishReason` (`.skipped` / `.completed(paletteID:)`) through `onFinish`, and `PaletteTabView` sets the flag and (Task 5) selects the palette.
- Replay: Settings signals `OnboardingReplayCoordinator`; `PaletteView` clears the flag in the Settings sheet's `onDismiss`.

- `isGenerated` on the onboarding palette (and its library colors) means AI-made: the deterministic builder path saves `false`.

## Open questions

- Should the orb camera use the front or back camera? Default: back.
- ~~Is "Replay onboarding" user-facing in Settings or debug-only?~~ Resolved: user-facing (Settings > About > Replay Onboarding).
- Free-tier generation size for the onboarding palette (default 4; keep within the free sizes from plan 013).
