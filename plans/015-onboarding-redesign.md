# Onboarding Redesign (015)

> Rework of plan 014's visuals and interaction. Plan 014's architecture stays: the cover, `OnboardingModel`, the finish reasons, the camera engine, generation, saving, the coach mark and the extras. This plan replaces the **view layer** of steps pull → generate.

## Why

The user reviewed 014 on 2026-10-08 and said it "looks very bad". Their specific asks:

1. **Island morph.** There must be a real morph from the Dynamic Island (or the notch) into the orb, like Telegram's profile photo morphing out of the Dynamic Island.
2. **Real glass.** The orb must be actual Liquid Glass, not a pink-filled ball.
3. **Small photo window.** The photo/camera must not fill the orb. It sits inside the orb in a **smaller circle with faded edges**.
4. **Tap to expand.** Tapping that small circle fades in a **larger image with faded, blurry edges**, together with **the same Liquid Glass color picker bubble the app already uses** (`PhotoColorPickerView.colorBubble`).
5. **Overall polish.** Fix the design, smoothness, interactivity and components overall.

Design guidance: the apple-design and emil-design-eng skills. Concretely:
- Springs everywhere, interruptible, with gesture velocity handed off.
- Critically damped by default; bounce only after a flick.
- Feedback on touch-down; enter/exit along the same path.
- Blur to bridge crossfades; never animate from scale 0.
- Reduce Motion becomes crossfades.

## Global constraints (unchanged from 014)

- **Platform:** iOS 17 deployment target. Every iOS 26 API sits behind `#available` or a `Compatibility/` shim. Don't edit the pbxproj.
- **Data:** persist only through `AppData`.
- **Concurrency:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and zero warnings.
- **Simulators:** use your own throwaway simulator with a scratch `-derivedDataPath`. Never touch other simulators; 208E09D6 is shared. Delete yours when done.
- **Tests:** the full `PalettesTests` suite must pass.
- **Branch:** `feature/onboarding-redesign`, from `feature/onboarding`, because PR #9 isn't merged yet. Commits end with the `Co-Authored-By` line you were given.
- **GenerateView must look exactly as it does on `dev`.** Onboarding no longer uses `GenerationOrbView`. Revert the onboarding-motivated changes to `GenerationOrbView.swift` and the orb-shell parts of `LiquidGlassCompat.swift` back to `dev`'s versions:
  - remove `backdrop`, `backdropID` and `interactive`;
  - remove `OrbShellBackground` and `OrbShellOverlay`;
  - restore `.liquidGlass(.clear, in: .circle)`.

  This also removes the iOS 17/18 visual change flagged in PR #9.
- **Debug jump.** Add a DEBUG-only launch argument, `-onboardingStart <pull|camera|picked|adjust|generate>`, which presents onboarding at that step using the sample image. Use it for screenshots.

## Visual system

| Element | Spec |
|---|---|
| Base background | `Color(.systemBackground)` in light mode. In dark mode use `Color(white: 0.09)`, so the black island goo stays visible. |
| Ambient field | `LiquidGradientView` at low intensity behind everything, fading in (0.8 s ease-out) only once the orb starts detaching. Clear glass needs something to refract. After a color is picked, it switches to `LiquidGradientView(colors:)` tinted with tones of the picked color: a crossfade with a 6 pt blur bridge. |
| Title | `.title.weight(.bold)`, `.tracking(-0.4)`, centered, `fixedSize(vertical)`. |
| Subtitle | `.body`, `.secondary`, centered, at most ~300 pt wide. |
| Step text change | Old and new text crossfade over 0.35 s. Each also animates blur 6→0 (in) or 0→6 (out) and offset y ±6. Use a custom `Transition`. |
| Primary button | Full width (max 340), 54 pt tall capsule, `.headline` label. iOS 26: `.buttonStyle(.glass)` (never `.glassProminent`). Earlier systems: a `PressableCapsuleStyle` with `.thinMaterial`, a hairline rim, and scale 0.97 on press. Put it in `GlassButtonCompat.swift` as `glassPrimaryButton()`. |
| Secondary button | Plain text button, `.subheadline.weight(.semibold)`, accent color, 44 pt hit area. |
| Skip | Top-trailing, `safeTop + 6`, trailing 20. Small 32 pt capsule, `.subheadline.weight(.medium)`, secondary color, glass (`glassCapsuleButton`). Hidden during the pull and the morph; fades in once the orb settles. |
| Layout | The orb is centered horizontally with its center at 34% of the height. Text and actions sit in a bottom-anchored `VStack`, with the primary action pinned via `safeAreaInset(edge: .bottom)` so it never jumps between steps. |
| Haptics | One per meaningful event, fired on the same frame as the visual: neck snap (`.impact(.rigid, 0.7)`), orb landing (`.impact(.soft)`), scan shutter (`.impact(.medium)`), color confirmed (`.success`), each palette color arriving (`.impact(.light)`). |

## 1. Island → orb morph (centerpiece)

New file: `Palettes/Views/Onboarding/IslandMorph.swift`.

### Geometry (`IslandGeometry`)
Derive it from the window's top safe-area inset and the screen size. The island and notch kinds apply only in portrait, and only on iPhones whose cutout is centered at the top. They are recognised by their screen size: 375×812, 414×896, 390×844, 428×926, 393×852, 430×932, 402×874, 440×956, and 420×912. Every other device pulls from the bezel. That includes iPad, home-button iPhones, landscape, and iPhone Duo, whose cutout is off-center.

| Top inset | Kind | Shape |
|---|---|---|
| ≥ 59 | Dynamic Island | Width 125, height 37, top = 14 if inset ≥ 62 else 11, fully rounded capsule. |
| 44–58 | Notch | Width 160, height 31, top 0, bottom corners radius 20. Draw the top 10 pt above the screen edge so it fuses with the bezel. |
| No centered cutout | Bezel | A band along the top edge, drawn just above the screen, 40 pt deep and 40 pt past each side. The drop starts tucked behind it, under the finger, and follows the finger sideways, staying 90 pt clear of the sides. The neck is 0.9× the drop's width, so the edge dips as a U. A shallow ellipse at the edge flares the shoulders and recoils as the neck thins. It pinches off like the island's neck, and the edge springs back flat. |

On iPad the bezel applies to every window, including resizable and floating ones, where the drop comes from the window's top edge. Only Reduce Motion skips the pull: the orb blurs and scales in from 0.9 at its resting position.

Draw the island shape **1 pt smaller** than the hardware on every side, so any mismatch hides behind it.

### Gooey rendering
Use a `Canvas` with the metaball recipe:

```swift
Canvas { ctx, size in
    ctx.addFilter(.alphaThreshold(min: 0.5, color: gooColor))   // black
    ctx.addFilter(.blur(radius: 9))
    ctx.drawLayer { layer in
        layer.fill(islandPath, with: .color(.black))
        layer.fill(Circle().path(in: blobRect), with: .color(.black))
    }
}
```

The blur and threshold make the island and the blob fuse with a smooth neck that stretches and then snaps as they separate. The Canvas exists only during the `.pull` step and the detach, and is removed afterwards.

### Motion model: a real interruptible spring
SwiftUI can't read the on-screen value of an animation, so drive the morph with a small integrator instead of `withAnimation`. This gives true interruption and velocity handoff.

- **`SpringValue`** (an ObservableObject):
  - **State:** `value`, `velocity`, `target`.
  - **Parameters:** Apple-style `response` and `dampingFraction`, converted to stiffness `(2π/response)²` and damping `4π·ζ/response`.
  - **Stepping:** semi-implicit Euler at display rate, using `TimelineView(.animation)` or a `CADisplayLink`, and only while not settled.
  - **Settling:** settled when |x − target| < 0.001 and |v| < 0.01.
  - **Tests:** unit-test it (it converges; it overshoots when ζ < 1 and not when ζ = 1).
- **`pull: SpringValue`** is in points:
  - During the drag, set `value` directly to `rubberBand(translation.height)` with no animation, so the blob tracks the finger 1:1.
  - The new drag starts from the **current** `value`. Store `pullAtDragStart` and add the translation to it, so grabbing a retracting blob doesn't jump.
- **On release**, project the end point with `current + (v/1000)·0.998/(1−0.998)` (Apple's projection).
  - **Projected end below 120 pt:** cancel. Spring `pull` back to 0 with response 0.35 and ζ 1, handing off the release velocity.
  - **Otherwise:** commit. Start `detach: SpringValue`, which runs 0→1 with response 0.6 and ζ 0.86. Hand it the release velocity normalised by the remaining distance (apple-design §5).
- **Reduce Motion:** no goo and no pull. Show a "Begin" primary button, and fade the orb in at its resting position.

### User correction (2026-10-08), which overrides the rest of this section
- **The morph happens while pulling.** The glass orb forms and grows during the drag itself, not after release.
- **The orb is clear Liquid Glass from the very first point of the pull.** It is **never** solid black or grey: there is no black overlay on the orb, no grey tint, and no fade from black.
- **Only the joined part is black.** That is the island plus the gooey neck connecting it to the orb, and it fades from black (at the island) into the glass (at the orb).
  - Render the goo Canvas (island, neck, and blob for the metaball shape) and mask it with a vertical `LinearGradient`: opaque at the island's bottom edge, fully clear by the blob's upper third.
  - The neck then reads as black liquid melting into glass, and the blob body never shows black.
  - Draw the real glass orb at the blob's frame from the start, on top of the faded goo. It is tiny when tucked under the island and grows with the pull.
- **Release past the threshold:** the neck stretches and snaps (rigid haptic), the black remainder retracts into the island, and the glass orb springs to its resting place and size.
- **Release short of it:** the orb shrinks back up into the island and the neck re-forms along the same path.
- Ignore the "Black → clear glass" bullet below, and the black-tint parts of the detach description.

### Blob shape over time
- **During the pull** (d = `pull.value`):
  - Blob radius = lerp(islandHeight/2, 34, min(d/140, 1)).
  - Blob center y = islandBottom − radius + d·0.85.
  - Center x = screen center.
  - At about d ≈ 110 the neck thins, but stays connected.
- **During the detach** (t = `detach.value`, which can overshoot slightly):
  - The center moves from the release position to the orb center.
  - The diameter grows from 2·radius to `orbDiameter`.
  - The goo neck snaps naturally within the first ~20% as the blob leaves. Fire the rigid haptic when the distance from the blob to the island first exceeds the snap distance (blob top − island bottom > 18).
- **Black → clear glass.** The real orb view (§2) is drawn at the blob's frame from t = 0.1 onwards:
  - **Black overlay** on the glass: opacity `1 − smoothstep(0.15, 0.75, t)`.
  - **Glass blur:** `(1 − smoothstep(0.1, 0.6, t)) · 10` pt.
  - **Canvas blob** opacity: `1 − smoothstep(0.1, 0.35, t)`, so the glass takes over from the goo without a visible swap.

  This is Telegram's "dark, blurred avatar sharpening as it leaves the island".
- **Landing.** When `detach` settles, fire the soft haptic. Fade in the ambient field, Skip, and the step text: the orb step's title and subtitle.

## 2. The glass orb

New file: `Palettes/Views/Onboarding/OnboardingOrbView.swift`. It replaces `OnboardingOrb.swift`; delete the old one.

- **Diameter:** `min(280, width·0.68)`. At accessibility Dynamic Type sizes, or when the height is under 700, use `min(220, width·0.56)`.
- **Real Liquid Glass.**
  - **iOS 26:** `Circle().fill(.clear).glassEffect(.clear.interactive(), in: .circle)`, drawn **on top of** the inner window, so the glass lens refracts and edge-magnifies the window and the ambient field behind it. Add a soft shadow (black 0.12, radius 24, y 12).
  - **iOS 17–25:** keep the orb clear rather than frosted:
    - a 1 pt rim, `AngularGradient` white 0.7 → 0.1 → 0.5;
    - a top-left specular arc: a blurred white ellipse at 0.35 opacity;
    - a faint inner shadow at the bottom edge.
  - No pastel liquid blobs.
- **Inner window.** A circle of diameter `orbDiameter·0.56`, centered, with a feathered edge:

  ```swift
  .mask(RadialGradient(stops: [.init(color: .black, location: 0.55),
                               .init(color: .clear, location: 1)],
                       center: .center, startRadius: 0, endRadius: windowDiameter/2))
  ```

  Its content depends on the state:
  - empty: nothing (the orb stays plain glass);
  - live camera: `OrbCameraPreview`;
  - frozen or picked photo: the image, scaled to fill;
  - picked color: a liquid fill. That's a circle of the color with a subtle radial highlight. It grows to `orbDiameter·0.78` as the color "fills" the orb (spring, response 0.5, ζ 0.9).
- **matchedGeometryEffect source.** The window gets `.matchedGeometryEffect(id: "photo", in: ns)` so the expanded picker (§4) grows from it.
- **Touch feedback.** On touch-down the orb scales to 0.97 (response 0.25, ζ 1), and springs back on release. The iOS 26 interactive glass adds its own highlight. Only the window is a tap target (when tappable). No drag-stretch.

## 3. Camera step

- **Permission not yet decided:**
  - title "See the world in color";
  - subtitle "Palettes uses your camera to find colors. Nothing is saved or uploaded.";
  - primary button "Continue", which then calls `requestAccess`;
  - secondary button "Choose a photo".
- **Live camera:**
  - title "Find a color";
  - subtitle "Point your camera at something you love.";
  - primary button "Scan" with an `camera.aperture` icon;
  - secondary button "Choose a photo";
  - the window shows the live preview.
- **Fallback** (denied, restricted, simulator, configuration failure): keep the existing wording for each case. The window shows the sample image or the picked photo, and the primary button "Use this photo" freezes it.
- **Scan:**
  1. A white flash inside the window: opacity 0 → 0.9 → 0 over 0.18 s.
  2. The medium haptic, on the same frame.
  3. The photo freezes in the window.
  4. Go straight to the **picked** state (below). No auto-advance timer.
- **Picked state.** The model needs a sub-state; extend `OnboardingStep`, or add a `photoFrozen` flag inside `.camera`.
  - Title "Pick your color", subtitle "Tap the photo to choose a spot."
  - The window pulses softly to show it can be tapped: scale 1 → 1.04 → 1, twice, then it stops. That's not a loop, and it's skipped under Reduce Motion.
  - Primary button "Choose color", which opens the picker. Secondary button "Retake".

## 4. Expanded photo picker (the core interaction)

New file: `Palettes/Views/Onboarding/OnboardingPhotoPicker.swift`.

### Shared loupe (`LiquidColorLoupe`)
Extract `PhotoColorPickerView.colorBubble` into `Palettes/Views/Components/LiquidColorLoupe.swift`. It's a clear glass circle of 112 with an 86 color disc inside, squishing with drag velocity and an under-damped spring back.
- It takes `color` and `velocity` as inputs.
- `PhotoColorPickerView` must use it with **no visual change**.
- Onboarding uses the same component.

### Opening (tap the window, or press "Choose color")
- The image animates with `matchedGeometryEffect(id: "photo")` from the small feathered window to a large frame:
  - width = screen width − 32;
  - height = min(screen height·0.58, width·1.25);
  - centered at the orb's center y, clamped to stay below Skip.
  - Spring: response 0.5, ζ 0.88.
- **Feathered, blurry edges.** Mask the large image with:

  ```swift
  RoundedRectangle(cornerRadius: 40, style: .continuous).fill(.black).padding(20).blur(radius: 20)
  ```

  Under the image, add a copy of the same image blurred by 30 at 0.6 opacity, so the edges dissolve into a soft glow rather than a hard fade. The feather amount also animates from the window's radial feather to this rounded-rect feather. To keep it simple, crossfade the two masks across the matched transition.
- **Behind it:** the orb scales to 0.94 and fades to 0.15 opacity, and the step text fades out with blur.
- **Loupe:**
  - The `LiquidColorLoupe` appears 84 pt above the current sample point. Enter with scale 0.6 → 1 plus opacity, never from 0.
  - Dragging anywhere on the image moves the sample point 1:1, clamped to the image rect, via `DragGesture(minimumDistance: 0)`.
  - Sample through `PixelSampler`, mapping the point with `PhotoLoupeGeometry` against the **large** frame.
  - A light haptic fires on touch-down only.
  - The initial sample is the image center, or the previous pick.
- **Bottom panel.** A glass panel (`.liquidGlass(.regular, in: .rect(cornerRadius: 28))`) shows:
  - a swatch;
  - the name (`ColorNamer`, updated when the drag ends), with `.contentTransition(.opacity)`;
  - the hex, monospaced, with `.contentTransition(.numericText())`;
  - and, below it, the primary "Use this color" button.

  It enters from the bottom: offset 24 plus opacity, spring response 0.45, ζ 1.
- **Close.** A circular glass `xmark` button at the top leading edge, or a tap on the scrim outside the image, reverses the matched geometry back into the window, along the same path.

### Use this color
1. The panel exits downwards (the reverse of its entrance).
2. The image collapses back into the window via the matched geometry.
3. The window's photo then crossfades with a blur bridge into the **liquid color fill**, which grows to 0.78 of the orb.
4. The success haptic fires.
5. The ambient field retints to the color.
6. Advance to `.adjust`.

## 5. Adjust step

- **Color identity** under the orb:
  - the color name in `.title2.weight(.bold)`;
  - the hex in `.subheadline` monospaced secondary, with `.contentTransition(.numericText())`.
- **Sliders.** Add a new reusable `Palettes/Views/Components/ColorRangeSlider.swift`. It replaces `AdjustmentSlider` in onboarding only; the rest of the app keeps `AdjustmentSlider`.
  - **Track:** a 30 pt capsule filled with a `LinearGradient` of the **actual** result colors, sampled at 0, 0.25, 0.5, 0.75 and 1 through `ColorAdjustment.apply`. Brightness runs darker → brighter of the current color; saturation runs muted → vivid. Give it an inner hairline stroke.
  - **Thumb:** a 30 pt circle. On iOS 26 it uses `glassEffect(.regular.interactive())`; earlier, white with a shadow. It is filled with the current adjusted color at 0.9 inset.
  - **Dragging:** 1:1, the whole track is draggable, and the thumb grows to 1.15 while pressed.
  - **Detents:** a selection haptic when crossing the 0.5 neutral detent. Values within ±0.02 of 0.5 snap to it on release.
  - **Labels:** SF Symbols at the ends: `sun.min` / `sun.max` and `drop` / `drop.fill`, plus a small title above the track. The value label reads "Neutral", or a signed percentage.
  - **Accessibility:** `accessibilityRepresentation { Slider(...) }` keeps VoiceOver and adjustable actions.
- **Primary button:** "Generate palette", with a `sparkles` icon.
- **Live updates:** the orb's liquid fill follows the adjusted color with a short spring (response 0.25).

## 6. Generate step

- **Liquid in the orb.** The liquid fill becomes drops: one per arriving color, each a blurred circle drifting slowly. Reuse the drift and bloom maths from `GenerationOrbView`, but inside the window/fill area of the new orb. No pastel neutral swirl.
- **Ready state:**
  - **Swatches:** the 4 colors **pour out of the orb** into a row of 4 circular swatches (56 pt, 12 pt spacing) under the orb. Each animates with `matchedGeometryEffect` from a small circle at the orb center to its slot. Stagger them 60 ms apart, spring response 0.5, ζ 0.82 (one small overshoot, since it's a "pour"). The light haptic fires per swatch.
  - **Name:** below the swatches, with a blur-in. AI-made names use `GeneratedGradient` as the foreground; otherwise `.primary`.
  - **Buttons:** primary "Open palette" (saves through the existing saver, then finishes with `.completed`); secondary "Try another" (regenerates). Keep the double-tap guard.
- **Failure:**
  - title "Couldn't make a palette";
  - primary "Try again";
  - secondary "Skip for now".

## 7. Remove and keep

- **Delete:**
  - `OnboardingOrb.swift`;
  - the old ripple, drop, marker and step-specific orb code in `OnboardingView.swift` that this replaces.

  Rewrite `OnboardingView` as a slim coordinator. Split the steps into small files, `OnboardingCameraStep.swift` and so on, each under ~250 lines.
- **Keep unchanged:**
  - `OnboardingModel` (extend it as needed);
  - `OrbCameraController`, `OrbCameraEngine` and `OrbCameraPreview`;
  - `OnboardingImageLoader`, `OnboardingGeneration`, `OnboardingSampling` (adjust the mapping to the new frames) and their tests;
  - the coach mark and the extras;
  - replay, and the `PaletteTabView` presenter.

## Execution phases (a review after each)

1. **Morph and shell:**
   - `SpringValue` with tests;
   - `IslandGeometry` with tests;
   - `IslandMorph` goo;
   - the new glass `OnboardingOrbView`;
   - the visual system (background, ambient field, text transition, buttons, Skip);
   - the camera step on the new layout;
   - the debug start argument;
   - the `GenerationOrbView` and `LiquidGlassCompat` revert.
2. **Picker and adjust:**
   - `LiquidColorLoupe` extraction, with `PhotoColorPickerView` unchanged;
   - the expanded photo picker;
   - `ColorRangeSlider`;
   - the adjust step.
3. **Generate and cleanup:**
   - the generate step;
   - deleting the old code;
   - full-suite run and screenshots;
   - a plan note.

## Verification (each phase)

- **Build and tests:** a clean build, zero warnings, and the full suite passing.
- **Motion:** record the morph with `xcrun simctl io <udid> recordVideo` while driving the pull with the simulator control tool's `touch_path`: a slow pull, a release short of the threshold, then a flick. ffmpeg isn't installed, so also take a burst of screenshots during the motion (e.g. every ~80 ms) to check the intermediate frames. Report what the frames show.
- **Screenshots:** save every step, light and dark, plus the open picker, to `advisor-plans/onboarding-screens/015/`. That folder is gitignored.
