# App Store screenshots

| Folder | Canvas | App Store slot |
|---|---|---|
| `iphone/light`, `iphone/dark` | 1320 × 2868 | iPhone 6.9" (scales down to the smaller sizes) |
| `ipad/light`, `ipad/dark` | 2064 × 2752 | iPad 13" |

Every screen exists in light and dark appearance; mix them (e.g. alternate) or pick one set. iPad has no 03 or 05.

Each screen `NN` has three layers on the same full-size canvas. Drop them into Pixelmator Pro at 0,0 in this order (bottom to top):

1. `NN-1-background.svg` — gradient glow + headline and subhead (editable text, SF Pro)
2. `NN-2-screen.png` — the capture, scaled, corner-rounded and already in position
3. `NN-3-frame.svg` — device bezel (+ Dynamic Island on iPhone); the screen area is transparent

`NN-preview.png` / `NN-preview.svg` show the finished composite. Unscaled simulator captures are in `raw/`.

## Regenerating

Captures come from a DEBUG-only demo library (`Palettes/App/ScreenshotSeed.swift`, in-memory, so the simulator's real library is untouched):

```
xcrun simctl launch <sim> com.halilbagosi.Palettes -screenshotSeed YES \
  -didCompleteOnboarding YES -didShowColorsIntro YES -didShowSearchIntro YES -didShowGenerateIntro YES \
  [-screenshotTab palettes|colors|search|generate] [-screenshotOpenPalette 0] [-screenshotSheet export|edit] \\
  [-screenshotExportFormat css|ase|…] [-paletteAddSource harmony] [-colorsSort hue]
```

Edit captions/glow colours in `make_shots.py`, then `python3 make_shots.py` (both devices, both themes); appearance comes from `xcrun simctl ui <sim> appearance light|dark` and `python3 render.py <outdir> <preview.svg…>`.
