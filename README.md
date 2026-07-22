# 🎨 Palettes

**A premium color palette manager and generator for iPhone and iPad.**

Craft, organize, and export color palettes with on-device Apple Intelligence, color-theory-guided harmony generation, a precision photo eyedropper, and UI/UX role tags built for designers — all synced privately through iCloud.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-green)
![AI](https://img.shields.io/badge/AI-on--device-purple)
![Sync](https://img.shields.io/badge/sync-iCloud-lightgrey)

---

## Features

### 🎼 Harmony-guided generation
- Pick a base color and Palettes builds a palette around it using real **color theory** — complementary, split-complementary, analogous, triadic, or monochromatic — instead of guesswork.
- **Auto mode** reads your base color and palette size to choose the right scheme: near-neutral bases get a monochromatic ladder plus an accent; larger palettes reserve a light background and a dark text color the way brand systems do.
- Prefer to drive? Override the scheme yourself from the generate screen.
- Every generated palette is **validated**: colors that are too perceptually close (< 12 ΔE) or too flat in brightness get repaired automatically, so results are always usable.

### 🧠 AI palette generation — fully on-device
- Generate from a text **vibe** ("Sunset in Tokyo"), from base colors, or both — powered by Apple's Foundation Models, so nothing ever leaves your device.
- Your chosen base colors are **locked**: they appear in the result exactly as picked.
- When a harmony plan is in play, the AI refines deterministic color targets rather than inventing from scratch — theory for structure, AI for nuance and naming.

### 🏷️ Role tags for UI/UX designers
- Tag any color with a role: **Primary, Secondary, Accent, Background, Surface, Text, Error, Success, Warning, Border** — or create your own custom tags, shared across every palette.
- One role per palette, enforced automatically: assign a role that's taken and it moves.
- Generated palettes arrive **pre-tagged** from the harmony plan — a brand-ready color system in one tap.
- **Search and filter by tag**: find every palette with an Accent, or browse by tag chips.

### 📷 Photo eyedropper & smart extraction
- Pick colors from any photo with a **full-screen loupe eyedropper** — drag anywhere, sample with pixel accuracy.
- Extraction clusters colors in **perceptual Lab space** and ranks them by *salience*, not raw area — so a small, vivid accent is no longer lost behind a large muted background.

### 🎛️ Color & palette management
- Edit with **HSL / RGB sliders** or direct hex input (3, 4, 6, and 8-digit formats).
- Organize with favorites, search, and flexible library layouts on iPhone and iPad.

### 📤 Export anywhere
Export in developer- and designer-ready formats:
`CSS variables` · `SCSS` · `Tailwind config` · `JSON` · `SwiftUI` · `SVG swatches` · `Coolors URL` · plain hex — or render palettes as shareable images.

Tagged colors export under their **role name**, so a color tagged Primary becomes `--primary` / `$primary` / `primary:` automatically, with collisions de-duplicated. JSON carries a dedicated `role` field alongside the color's own name.

### 🔮 Liquid Glass generation experience
- A custom **Metal shader** renders a domain-warped, interactive pastel backdrop during generation.
- An iridescent **glass orb** with a chromatic prism rim streams each color live as it's produced.
- Fluid, interruptible transitions between input, loading, and reveal stages.

### 🗣️ Siri, Shortcuts & Spotlight
- Six App Intents: Generate Palette, Create Palette, Save Color, Open Palette, Find Palettes, Get Color Hex.
- Try *"Generate a palette in Palettes"* or *"What's the hex code of Deep Teal in Palettes?"*
- Palettes and colors are indexed in Spotlight.

### 💻 Built for iPhone *and* iPad
- Adaptive sidebar navigation on iPadOS, plus hardware keyboard shortcuts (⌘1–⌘4).

---

## Screenshots

> Coming soon.

---

## Requirements

| | |
|---|---|
| **iOS** | 17.0+ (AI generation requires iOS 26+ with Apple Intelligence) |
| **Xcode** | 17.0+ with the latest iOS SDK |
| **AI hardware** | iPhone 15 Pro or later, M-series iPad, or Apple Silicon Mac (Simulator) |

Role tags, photo extraction, and export all work on iOS 17. Palette *generation* — harmony-guided or otherwise — requires iOS 26+ with Apple Intelligence: `PaletteGenerator` and the Generate tab are gated behind `@available(iOS 26.0, *)` and throw if Apple Intelligence isn't available, so there's no lower-availability fallback that still produces palettes.

---

## Getting started

```bash
git clone https://github.com/halilbagosi/Palettes.git
cd Palettes
open Palettes.xcodeproj
```

Select an iOS 17+ simulator or device and hit **⌘R**.

### Running tests

```bash
xcodebuild test -project Palettes.xcodeproj -scheme Palettes \
  -destination "platform=iOS Simulator,name=<simulator>"
```

Unit tests cover the harmony engine, palette validation and repair, role persistence, exports, hex parsing, color adjustment and naming, image extraction, search matching, App Intents, and photo-loupe geometry.

---

## Architecture

Clean **MVVM** with unidirectional state flow in SwiftUI. `AppData` is the single source of truth: it publishes value-type view models and owns all persistence through a debounced SwiftData write-back.

```
Palettes/
├── App/            # Entry point, AppData (global state), SwiftData persistent store
├── Models/         # ColorRole and shared value types
├── ViewModels/     # Value-type models for colors and palettes
├── Views/
│   ├── Main/       # Tab navigation, search + tag filtering
│   ├── Palette/    # Palette list, detail, creation, role tagging
│   ├── Color/      # Color list, editing, AI generation
│   └── Components/ # Swatches, sliders, photo picker, role badge/picker, generation orb
├── Managers/       # ColorHarmony, PaletteGenerator, PaletteValidation, PaletteExporter
├── Intents/        # App Intents + Spotlight entity indexing
├── Compatibility/  # iOS 26+ API shims (Liquid Glass, Apple Intelligence)
├── Extensions/     # Color utilities, hue categories
└── Utilities/      # Metal shaders, Lab-based image extraction, hex parsing, search matching
```

---

## Sync & privacy

- **Private iCloud sync** via CloudKit (`iCloud.com.halilbagosi.Palettes`) — your palettes are visible only to you.
- **Graceful fallback** to a local on-device store (or in-memory library) when iCloud is unavailable.
- **No servers, no tracking**: AI generation, harmony math, color extraction, and rendering all happen on-device.
