# 🎨 Palettes

**A premium color palette manager and generator for iPhone and iPad.**

Craft, organize, and export color palettes with on-device Apple Intelligence, a liquid-glass generation experience, and a precision photo eyedropper — all synced privately through iCloud.

![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![UI](https://img.shields.io/badge/UI-SwiftUI-green)
![AI](https://img.shields.io/badge/AI-on--device-purple)
![Sync](https://img.shields.io/badge/sync-iCloud-lightgrey)

---

## Features

### 🧠 AI palette generation — fully on-device
- Generate palettes from a text **vibe** ("Sunset in Tokyo"), from base colors you've saved, or both — powered by Apple's Foundation Models (`LanguageModelSession`), so nothing ever leaves your device.
- Your chosen base colors are **locked**: they appear in the result exactly as picked, and the AI fills in complementary colors around them.
- Every color arrives with an evocative name and a precise hex code; palettes are always filled to your selected size.

### 🔮 Liquid-glass generation experience
- A custom **Metal shader** renders a domain-warped, interactive pastel backdrop during generation.
- An iridescent **glass orb** with a chromatic prism rim streams each color live as the model produces it.
- Fluid, interruptible transitions between input, loading, and reveal stages.

### 📷 Photo eyedropper
- Pick colors from any photo with a **full-screen loupe eyedropper** — drag anywhere, sample with pixel accuracy, and preview the color in a liquid-glass swatch before saving.
- Automatic extraction of dominant colors from camera captures and imported images.

### 🎛️ Color & palette management
- Edit colors with **HSL / RGB sliders** or direct hex input (3, 4, 6, and 8-digit formats supported).
- Organize with favorites, search, and flexible library layouts on iPhone and iPad.
- Rename, reorder, and refine palettes at any time.

### 📤 Export anywhere
Export palettes in developer- and designer-ready formats:
`CSS variables` · `SCSS` · `Tailwind config` · `JSON` · `SwiftUI` · `SVG swatches` · `Coolors URL` · plain hex — or render palettes as shareable images.

### 🗣️ Siri, Shortcuts & Spotlight
- Six App Intents: Generate Palette, Create Palette, Save Color, Open Palette, Find Palettes, and Get Color Hex.
- Try *"Generate a palette in Palettes"* or *"What's the hex code of Deep Teal in Palettes?"*
- Palettes and colors are indexed in Spotlight for instant system-wide search.

### 💻 Built for iPhone *and* iPad
- Adaptive sidebar navigation on iPadOS.
- Hardware keyboard shortcuts (⌘1–⌘4) for tab switching.

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

On devices without Apple Intelligence, everything except AI generation works normally.

---

## Getting started

```bash
git clone https://github.com/halilbagosi/Palettes.git
cd Palettes
open Palettes.xcodeproj
```

Select an iOS 17+ simulator or device and hit **⌘R**. For on-device AI generation, run on an iOS 26+ device with Apple Intelligence enabled and models downloaded.

### Running tests

```bash
xcodebuild test -project Palettes.xcodeproj -scheme Palettes \
  -destination "platform=iOS Simulator,name=<simulator>"
```

Unit tests cover palette exports, hex parsing, color adjustment and naming, view-model invariants, persistence, App Intents, and photo-loupe geometry.

---

## Architecture

Clean **MVVM** with unidirectional state flow in SwiftUI. `AppData` is the single source of truth: it publishes value-type view models and owns all persistence through a debounced SwiftData write-back.

```
Palettes/
├── App/            # Entry point, AppData (global state), SwiftData persistent store
├── ViewModels/     # Value-type models for colors and palettes
├── Views/
│   ├── Main/       # Tab navigation, search
│   ├── Palette/    # Palette list, detail, creation
│   ├── Color/      # Color list, editing, AI generation
│   └── Components/ # Swatches, sliders, photo color picker, generation orb
├── Managers/       # PaletteGenerator (AI), PaletteExporter, image rendering, toasts
├── Intents/        # App Intents + Spotlight entity indexing
├── Compatibility/  # iOS 26+ API shims (Liquid Glass, Apple Intelligence)
├── Extensions/     # Color utilities, hue categories
└── Utilities/      # Metal shaders, image color extraction, hex parsing
```

---

## Sync & privacy

- **Private iCloud sync** via CloudKit (`iCloud.com.halilbagosi.Palettes`) — your palettes are visible only to you.
- **Graceful fallback** to a local on-device store (or in-memory library) when iCloud is unavailable.
- **No servers, no tracking**: AI generation, color extraction, and rendering all happen on-device.
