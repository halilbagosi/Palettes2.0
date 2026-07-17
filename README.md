# 🎨 Palettes 2.0

A premium color palette manager and generator, built for iOS 17+ and designed to shine with the latest Liquid Glass visuals on iOS 26/27. **Palettes 2.0** leverages on-device Apple Intelligence (Foundation Models) and custom Metal shaders to deliver a stunning, interactive, and modern palette-creation experience.

---

## 🌟 Key Features

### 🧠 On-Device AI Palette Generation
- **Apple Intelligence Integration**: Uses Apple’s local language models (`SystemLanguageModel` and `LanguageModelSession`) to generate custom color palettes directly on-device.
- **Multi-Input Synthesis**: Generate palettes based on a text-based "vibe" description, a selection of base colors, or colors extracted from camera captures and images.
- **Intelligent Color Parsing**: Validates color spaces and automatically formats results with customized names and precise HEX codes.

### 🔮 Liquid Glass Generation Experience
- **Metal-Shader Backdrop**: Features a custom Metal fragment shader (`PaletteShaders.metal`) that generates a domain-warped, interactive pastel sine field.
- **Iridescent Glass Orb**: Employs iOS 27 `.glassEffect` materials combined with a rotating, chromatic prism-edged rim that responds to timeline updates during AI generation.
- **Seamless Stage Transitions**: Immersive full-screen generation overlay with fluid transition states when moving between inputs, loading states, and generated results.

### 🗂️ Color & Palette Management
- **Interactive Editing**: Modify individual colors, adjust HSL/RGB values via custom sliders, and parse HEX inputs seamlessly.
- **Search & Filter**: Quickly search through existing colors and palettes to find the perfect shade.
- **Export & Share**: Share custom palettes using native share sheets, or render color swatches as images on-device.

### 🗣️ Siri & Shortcuts
- **App Intents**: Six intents power Siri and the Shortcuts app — Generate Palette, Create Palette, Save Color, Open Palette, Find Palettes, and Get Color Hex.
- **Siri Phrases**: Try "Generate a palette in Palettes," "Save a color in Palettes," "Open [palette name] in Palettes," or "What's the hex code of [color name] in Palettes."
- **Shortcuts App**: All six actions appear under the Palettes app in Shortcuts for building custom automations and workflows.
- **Spotlight Search**: Palettes and colors are indexed for Spotlight, so you can find and jump to them directly from system search.

### 💻 Multi-Device Ergonomics
- **Adaptable Sidebar Layout**: Native iPadOS support that adapts seamlessly between compact and expanded navigation styles.
- **Keyboard Shortcuts**: Native support for ⌘1 through ⌘4 keys to quickly switch between tabs on iPad hardware keyboards.

---

## 🏗️ Architecture & Project Structure

The app is built using clean **MVVM** patterns paired with unidirectional state flow driven by SwiftUI:

```
Palettes/
├── App/
│   ├── MyApp.swift               # Application Entrypoint
│   └── AppData.swift             # Global state (ObservableObject) managing palettes/colors
├── ViewModels/
│   ├── ColorViewModel.swift      # State and behaviors for single colors
│   └── PaletteViewModel.swift    # State and behaviors for color palettes
├── Views/
│   ├── Main/                     # PaletteTabView, SearchView
│   ├── Palette/                  # PaletteView, PaletteDetailView, NewPaletteView
│   ├── Color/                    # ColorsView, ColorEditView, GenerateView
│   └── Components/               # Reusable swatches, sliders, sheets, and:
│       └── Generation/           # LiquidGradientView, GenerationOrbView, GenerationExperienceView
├── Managers/
│   ├── PaletteGenerator.swift    # On-device Foundation Model session wrapper
│   ├── PaletteImageRenderer.swift# Image export generation logic
│   └── ToastManager.swift        # Global UI notification toasts overlay
└── Utilities/
    ├── PaletteShaders.metal      # GPU-accelerated liquid gradient shader
    ├── ImageColorExtractor.swift # Image pixel color extraction engine
    └── HEXParser.swift           # Hexadecimal string decoder
```

---

## 🛠️ System Requirements

- **iOS Target**: iOS 17.0+ (minimum deployment target)
- **IDE**: Xcode 17.0+ (with the latest iOS SDK)
- **On-Device AI Generation**: Requires iOS 26.0+ on a compatible Apple Silicon device (iPhone 15 Pro+, iPad with M-series chips, or Apple Silicon Mac running the Simulator) with Apple Intelligence enabled and language models downloaded. On earlier iOS versions the app runs normally with AI generation unavailable.

---

## 🚀 Setup & Installation

1. Clone the repository to your Mac:
   ```bash
   git clone https://github.com/halilbagosi/Palettes.git
   cd Palettes
   ```
2. Open `Palettes.xcodeproj` in **Xcode**:
   ```bash
   open Palettes.xcodeproj
   ```
3. Set the build target to an iOS 17.0+ Simulator or a connected developer-enabled device (iOS 26+ for on-device AI generation).
4. Clean and run the project:
   - Use shortcut `⌘R` or click the **Play** button in Xcode.

---

## ☁️ Sync & Privacy

- **iCloud Sync**: Palettes and colors sync across your devices via your private CloudKit database (container `iCloud.com.halilbagosi.Palettes`). Only you can access this data — it is never shared with any third party.
- **Local Fallback**: If iCloud is unavailable, the app falls back to a purely local on-device store, and if that is also unavailable, to a session-only in-memory library.
- **On-Device AI**: Palette generation runs entirely on-device via Apple's Foundation Models — no palette data, images, or prompts are sent to any external server.

---

## 🧪 Testing and Verification

- The project compiles without dynamic device-sniffing hooks. All mock language session configurations default to local models if hardware gates pass.
- Metal shaders compile automatically into the app’s default library during compilation.
- **Manual Verification Checklist**:
  1. Open the **Generate** tab.
  2. Enter a vibe (e.g., *"Sunset in Tokyo"*), choose a base color, or upload an image.
  3. Hit **Generate** to watch the GPU-accelerated liquid glass transition.
  4. Edit, regenerate, or save the resulting palette to check local data persistence.
