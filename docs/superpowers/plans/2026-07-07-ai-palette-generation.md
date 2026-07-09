# AI Palette Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the Generate tab to create complementary color palettes on-device with Apple's Foundation Models framework, preview them in a sheet, and save them.

**Architecture:** A stateless `PaletteGenerator` enum wraps `LanguageModelSession` guided generation (`@Generable` output types) and returns a validated `PaletteViewModel`. `GenerateView` gathers inputs (selected colors, vibe text, photo-extracted colors), calls the generator, and presents `GeneratedPaletteSheet` for preview/regenerate/save. The tab is added to the single (previously dead-branched) `TabView`.

**Tech Stack:** SwiftUI, FoundationModels (iOS 26+; deployment target is iOS 27), existing utilities (`Color(hex:)`, `ColorNamer`, `ImageColorExtractor`, `ToastManager`).

## Global Constraints

- Deployment target: iOS 27.0 — no `#available(iOS 18/26)` guards needed anywhere.
- No unit test target exists and none is added; the test cycle for every task is: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build` must print `** BUILD SUCCEEDED **` with no `error:` lines.
- The repo has unrelated staged changes. Commits MUST use explicit pathspecs (`git commit -m "..." -- <paths>`) so only this feature's files are committed.
- Follow existing style: 4-space indent, `// MARK:` sections, `.ultraThinMaterial`/`.thinMaterial` backgrounds, monospaced hex labels.

---

### Task 1: AppError cases

**Files:**
- Modify: `Palettes/Utilities/AppError.swift`

**Interfaces:**
- Produces: `AppError.aiUnavailable`, `AppError.generationFailed` (used by Tasks 2–4).

- [ ] **Step 1: Add the two cases and descriptions**

In `Palettes/Utilities/AppError.swift`, add to the enum after `case emptyPaletteName`:

```swift
    case aiUnavailable
    case generationFailed
```

And add to the `switch` in `errorDescription` before the closing brace:

```swift
        case .aiUnavailable:
            return "Apple Intelligence is not available on this device right now."
        case .generationFailed:
            return "Couldn't generate a palette. Please try again."
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Palettes/Utilities/AppError.swift
git commit -m "feat: add AI generation error cases" -- Palettes/Utilities/AppError.swift
```

---

### Task 2: PaletteGenerator backend

**Files:**
- Create: `Palettes/Managers/PaletteGenerator.swift`

**Interfaces:**
- Consumes: `AppError.aiUnavailable` / `.generationFailed` (Task 1), `Color(hex:)` (`Palettes/Utilities/HEXParser.swift`), `ColorNamer.name(forHex:)`, `PaletteViewModel`.
- Produces: `PaletteGenerator.BaseColor(hex:name:)`, `PaletteGenerator.generate(baseColors:size:vibe:) async throws -> PaletteViewModel` (used by Task 4).

- [ ] **Step 1: Create the file with the full implementation**

```swift
//
//  PaletteGenerator.swift
//  Palettes
//

import Foundation
import SwiftUI
import FoundationModels

// MARK: - Guided generation output types

@Generable
struct GeneratedColor {
    @Guide(description: "A 6-digit RGB hex color code with a leading #, for example #4A90D9")
    var hex: String

    @Guide(description: "A short, evocative name for this color, like 'Electric Blue'")
    var name: String
}

@Generable
struct GeneratedPalette {
    @Guide(description: "A short, evocative two or three word name for the palette")
    var name: String

    @Guide(description: "The colors that make up the palette")
    var colors: [GeneratedColor]
}

// MARK: - Generator

/// Generates complementary color palettes on-device using Foundation Models.
enum PaletteGenerator {

    struct BaseColor {
        let hex: String
        let name: String
    }

    static func generate(
        baseColors: [BaseColor],
        size: Int,
        vibe: String?
    ) async throws -> PaletteViewModel {
        guard case .available = SystemLanguageModel.default.availability else {
            throw AppError.aiUnavailable
        }

        let instructions = """
        You are an expert color designer creating harmonious color palettes. \
        Every palette you produce must feel cohesive: complementary hues, \
        balanced lightness, and good contrast between neighboring colors.
        """

        var prompt = "Create a color palette of exactly \(size) colors."
        if !baseColors.isEmpty {
            let list = baseColors.map { "\($0.hex) (\($0.name))" }.joined(separator: ", ")
            prompt += " Build the palette around these colors and include them in it: \(list)."
            prompt += " Fill the remaining slots with complementary colors that harmonize with them."
        }
        if let vibe = vibe?.trimmingCharacters(in: .whitespacesAndNewlines), !vibe.isEmpty {
            prompt += " The palette should capture this vibe: \(vibe)."
        }

        let session = LanguageModelSession(instructions: instructions)

        let generated: GeneratedPalette
        do {
            generated = try await session.respond(to: prompt, generating: GeneratedPalette.self).content
        } catch {
            throw AppError.generationFailed
        }

        var colors: [Color] = []
        var hexCodes: [String] = []
        var colorNames: [String] = []

        for item in generated.colors.prefix(max(size, 2)) {
            var hex = item.hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if !hex.hasPrefix("#") { hex = "#" + hex }
            guard let color = Color(hex: hex) else { continue }
            colors.append(color)
            hexCodes.append(hex)
            let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            colorNames.append(trimmed.isEmpty ? ColorNamer.name(forHex: hex) : trimmed)
        }

        guard colors.count >= 2 else { throw AppError.generationFailed }

        let paletteName = generated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PaletteViewModel(
            name: paletteName.isEmpty ? "Generated Palette" : paletteName,
            colors: colors,
            hexCodes: hexCodes,
            colorNames: colorNames
        )
    }
}
```

Note: if the beta SDK's `@Guide` signature differs (e.g. rejects `description:` label), adjust to the compiler's suggestion — the descriptions are the only guides used, deliberately: hex validity is enforced by post-validation, not regex guides.

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Palettes/Managers/PaletteGenerator.swift
git commit -m "feat: add Foundation Models palette generator" -- Palettes/Managers/PaletteGenerator.swift
```

---

### Task 3: GeneratedPaletteSheet

**Files:**
- Create: `Palettes/Views/Components/GeneratedPaletteSheet.swift`

**Interfaces:**
- Consumes: `PaletteViewModel`, `AppData.palettes`, `ToastManager.shared.show(_:icon:)`.
- Produces: `GeneratedPaletteSheet(palette:onRegenerate:)` where `onRegenerate: () async throws -> PaletteViewModel` (used by Task 4).

- [ ] **Step 1: Create the file with the full implementation**

```swift
//
//  GeneratedPaletteSheet.swift
//  Palettes
//

import SwiftUI

/// Preview sheet for an AI-generated palette with Regenerate and Save actions.
struct GeneratedPaletteSheet: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    @State var palette: PaletteViewModel
    let onRegenerate: () async throws -> PaletteViewModel

    @State private var isRegenerating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    swatchStrip
                    colorList
                }
                .padding()
                .padding(.bottom, 80)
            }
            .navigationTitle(palette.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isRegenerating)
                }
            }
            .safeAreaInset(edge: .bottom) { regenerateButton }
        }
    }

    // MARK: - Swatch Strip

    private var swatchStrip: some View {
        HStack(spacing: 0) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                Rectangle().fill(palette.colors[i])
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .opacity(isRegenerating ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }

    // MARK: - Color List

    private var colorList: some View {
        VStack(spacing: 10) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.colors[i].gradient)
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(i < palette.colorNames.count ? palette.colorNames[i] : "Color \(i + 1)")
                            .font(.system(size: 15, weight: .semibold))
                        Text(i < palette.hexCodes.count ? palette.hexCodes[i] : "")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
        .opacity(isRegenerating ? 0.4 : 1)
        .animation(.easeInOut(duration: 0.2), value: isRegenerating)
    }

    // MARK: - Regenerate

    private var regenerateButton: some View {
        Button {
            regenerate()
        } label: {
            HStack(spacing: 8) {
                if isRegenerating {
                    ProgressView()
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isRegenerating ? "Generating…" : "Regenerate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isRegenerating)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func save() {
        appData.palettes.append(palette)
        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        dismiss()
    }

    private func regenerate() {
        guard !isRegenerating else { return }
        isRegenerating = true
        Task {
            do {
                let newPalette = try await onRegenerate()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    palette = newPalette
                }
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
            isRegenerating = false
        }
    }
}

#Preview {
    GeneratedPaletteSheet(
        palette: PaletteViewModel(
            name: "Midnight Ocean",
            colors: [Color(hex: "1A1A70")!, Color(hex: "007AFF")!, Color(hex: "99FA99")!],
            hexCodes: ["#1A1A70", "#007AFF", "#99FA99"],
            colorNames: ["Midnight", "Electric Blue", "Pastel Mint"]
        ),
        onRegenerate: {
            try await Task.sleep(for: .seconds(1))
            return PaletteViewModel(
                name: "Regenerated",
                colors: [Color(hex: "FF5D00")!, Color(hex: "FF0080")!],
                hexCodes: ["#FF5D00", "#FF0080"],
                colorNames: ["Sunset Orange", "Hot Pink"]
            )
        }
    )
    .environmentObject(AppData())
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Palettes/Views/Components/GeneratedPaletteSheet.swift
git commit -m "feat: add generated palette preview sheet" -- Palettes/Views/Components/GeneratedPaletteSheet.swift
```

---

### Task 4: Wire up GenerateView

**Files:**
- Modify: `Palettes/Views/Color/GenerateView.swift`

**Interfaces:**
- Consumes: `PaletteGenerator.generate(baseColors:size:vibe:)` and `PaletteGenerator.BaseColor` (Task 2), `GeneratedPaletteSheet(palette:onRegenerate:)` (Task 3), `ImageColorExtractor.extractColors(from:count:)` → `[ExtractedColor]` with `.hex`/`.name`, `SystemLanguageModel.default.availability`.

- [ ] **Step 1: Add import and state**

Add below `import PhotosUI`:

```swift
import FoundationModels
```

Add below `@State private var showCamera = false`:

```swift
    @State private var isGenerating = false
    @State private var generatedPalette: PaletteViewModel?
```

- [ ] **Step 2: Gate the body on model availability and present the sheet**

Replace the `body` property with:

```swift
    var body: some View {
        NavigationStack {
            Group {
                switch SystemLanguageModel.default.availability {
                case .available:
                    generateContent
                case .unavailable(let reason):
                    unavailableView(for: reason)
                }
            }
            .background { animatedBackground }
            .navigationTitle("Generate")
            .onAppear {
                withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                    glowPhase = 1
                }
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: true)) {
                    bgPhase = 1
                }
            }
        }
        .sheet(item: $generatedPalette) { palette in
            GeneratedPaletteSheet(palette: palette, onRegenerate: performGeneration)
                .environmentObject(appData)
        }
    }

    private var generateContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                descriptionText
                    .padding(.top, 4)
                paletteSizeSection
                colorsSection
                vibeInputSection
                    .padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .disabled(isGenerating)
    }

    // MARK: - Unavailable State

    private func unavailableView(for reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        let message: String
        switch reason {
        case .deviceNotEligible:
            message = "This device doesn't support Apple Intelligence, so palettes can't be generated here."
        case .appleIntelligenceNotEnabled:
            message = "Turn on Apple Intelligence in Settings to generate palettes."
        case .modelNotReady:
            message = "The Apple Intelligence model is still getting ready. Try again in a moment."
        @unknown default:
            message = "Apple Intelligence is currently unavailable."
        }
        return ContentUnavailableView {
            Label("Apple Intelligence Unavailable", systemImage: "apple.intelligence")
        } description: {
            Text(message)
        }
    }
```

- [ ] **Step 3: Wire the send button and add the image chip**

Replace `vibeInputSection` and `vibeTextField` with:

```swift
    private var vibeInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = selectedImage {
                imageChip(image)
            }
            HStack(spacing: 10) {
                vibeTextField
                imageMenuButton
            }
        }
        .padding(.horizontal)
    }

    private var hasInput: Bool {
        !selectedColorIDs.isEmpty
            || !vibeDescription.trimmingCharacters(in: .whitespaces).isEmpty
            || selectedImage != nil
    }

    private var vibeTextField: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.intelligence")
                .font(.title3)
                .foregroundStyle(glowGradient)

            TextField("Describe palette vibe!", text: $vibeDescription)
                .font(.headline)

            if hasInput {
                Button {
                    startGeneration()
                } label: {
                    if isGenerating {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(glowGradient)
                    }
                }
                .disabled(isGenerating)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasInput)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }

    private func imageChip(_ image: UIImage) -> some View {
        HStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Colors will be pulled from this photo")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedImage = nil
                    photosPickerItem = nil
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }
```

- [ ] **Step 4: Add the generation actions**

Add before the closing brace of `GenerateView`:

```swift
    // MARK: - Generation

    private func startGeneration() {
        guard !isGenerating else { return }
        isGenerating = true
        Task {
            do {
                generatedPalette = try await performGeneration()
            } catch {
                ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            }
            isGenerating = false
        }
    }

    private func performGeneration() async throws -> PaletteViewModel {
        var baseColors: [PaletteGenerator.BaseColor] = appData.colors
            .filter { selectedColorIDs.contains($0.id) }
            .map { PaletteGenerator.BaseColor(hex: $0.HEX, name: $0.name) }

        if let image = selectedImage {
            let extracted = try ImageColorExtractor.extractColors(from: image, count: 4)
            baseColors += extracted.map { PaletteGenerator.BaseColor(hex: $0.hex, name: $0.name) }
        }

        return try await PaletteGenerator.generate(
            baseColors: baseColors,
            size: Int(paletteSize),
            vibe: vibeDescription
        )
    }
```

Note: `.sheet(item:)` requires the closure parameter, but `GeneratedPaletteSheet` takes the palette as `@State` initial value — passing `palette` from the closure is correct; regeneration inside the sheet updates its local copy.

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Palettes/Views/Color/GenerateView.swift
git commit -m "feat: wire Generate tab to Foundation Models generation" -- Palettes/Views/Color/GenerateView.swift
```

---

### Task 5: Enable the Generate tab

**Files:**
- Modify: `Palettes/Views/Main/PaletteTabView.swift`

**Interfaces:**
- Consumes: `GenerateView` (Task 4), `TabValue.generate` (already exists).

- [ ] **Step 1: Replace the whole struct body**

Replace `PaletteTabView` (keep the `TabValue` enum and `#Preview` below it) with:

```swift
struct PaletteTabView: View {

    @StateObject private var appData = AppData()

    var body: some View {
        TabView(selection: $appData.activeTab) {
            Tab("Palettes", systemImage: "swatchpalette.fill", value: .palettes) {
                PaletteView()
            }

            Tab("Colors", systemImage: "circle.grid.cross.fill", value: .colors) {
                ColorsView()
            }

            Tab("Generate", systemImage: "sparkles", value: .generate) {
                GenerateView()
            }

            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .environmentObject(appData)
    }
}
```

This deletes the `supportsAppleIntelligence` / `isDeviceCapable` sysctl code and both dead `#available` branches (deployment target is iOS 27).

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Palettes/Views/Main/PaletteTabView.swift
git commit -m "feat: enable Generate tab, drop dead availability branches" -- Palettes/Views/Main/PaletteTabView.swift
```

---

### Task 6: End-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Full clean build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|warning|BUILD"`
Expected: `** BUILD SUCCEEDED **`, no errors or warnings.

- [ ] **Step 2: Manual run checklist (simulator or device)**

- Generate tab appears with sparkles icon.
- With Apple Intelligence available: select 1 color → arrow button appears → generates → sheet shows named palette including a color close to the base → Save adds it to Palettes tab with toast.
- Vibe-only generation works (no colors selected).
- Photo input shows the chip; generation uses photo colors; ✕ removes it.
- Regenerate replaces the sheet contents.
- With Apple Intelligence off: tab shows the ContentUnavailableView explanation.
