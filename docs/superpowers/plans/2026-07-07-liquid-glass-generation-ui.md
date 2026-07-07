# Liquid Glass Generation Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the palette-generation flow with iOS 27 Liquid Glass + a shader-driven full-screen waiting orb, unifying waiting and result into one full-screen experience.

**Architecture:** A Metal `colorEffect` shader renders a flowing pastel field, wrapped by `LiquidGradientView` (TimelineView-driven). `GenerationOrbView` composes it with a `glassEffect` orb and rotating chromatic rim. `GenerationExperienceView` is a `fullScreenCover` that runs the generation closure, morphing orb → result (glass buttons, save/regenerate). `GenerateView` presents it and gets glass controls; `GeneratedPaletteSheet` is deleted.

**Tech Stack:** SwiftUI (iOS 27 target), Metal stitchable shaders, Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)` / `.glassProminent`).

## Global Constraints

- Deployment target iOS 27.0 — no availability guards.
- No unit test target; every task's test cycle is `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build` printing `** BUILD SUCCEEDED **` with no `error:` lines.
- Repo has unrelated staged changes: commits MUST use explicit pathspecs (`git commit -m "..." -- <paths>`).
- A parallel session is editing `AddColorToPaletteSheet.swift`, `NewPaletteView.swift`, `NewColorView.swift`, `ColorsView.swift`, `PaletteView.swift` (deprecation fixes) — do not touch those files.
- Existing style: 4-space indent, `// MARK:` sections.

---

### Task 1: Metal shader + LiquidGradientView

**Files:**
- Create: `Palettes/Utilities/PaletteShaders.metal`
- Create: `Palettes/Views/Components/Generation/LiquidGradientView.swift`

**Interfaces:**
- Produces: `LiquidGradientView(speed: Double = 1, intensity: Double = 1)` — animated full-bleed gradient view (used by Tasks 2, 3). Shader entry point `liquidGradient(position, color, size, time, intensity)`.

- [ ] **Step 1: Create the shader file**

```metal
//
//  PaletteShaders.metal
//  Palettes
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Flowing pastel field: domain-warped sines through a cosine palette.
// Premultiplied-alpha output; `intensity` scales overall strength.
[[ stitchable ]] half4 liquidGradient(
    float2 position,
    half4 color,
    float2 size,
    float time,
    float intensity
) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    float t = time * 0.35;

    float2 p = uv * 3.0;
    p.x += sin(p.y * 1.7 + t * 1.3) * 0.6;
    p.y += cos(p.x * 1.4 - t) * 0.6;

    float n1 = sin(p.x + t) * cos(p.y - t * 0.7);
    float n2 = sin((p.x + p.y) * 0.8 + t * 1.6);
    float band = 0.5 + 0.5 * sin(n1 * 2.2 + n2 * 1.8 + t);

    float3 phase = float3(0.00, 0.33, 0.67);
    float3 col = 0.72 + 0.28 * cos(6.28318 * (band + phase + n1 * 0.15));

    float a = clamp(intensity * (0.30 + 0.45 * band), 0.0, 1.0);
    return half4(half3(col) * a, a);
}
```

- [ ] **Step 2: Create the wrapper view**

```swift
//
//  LiquidGradientView.swift
//  Palettes
//

import SwiftUI

/// Animated, shader-driven flowing pastel gradient. Renders full-bleed in its frame.
struct LiquidGradientView: View {
    var speed: Double = 1
    var intensity: Double = 1

    private let startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { geo in
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.liquidGradient(
                        .float2(Float(geo.size.width), Float(geo.size.height)),
                        .float(Float(timeline.date.timeIntervalSince(startDate) * speed)),
                        .float(Float(intensity))
                    ))
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LiquidGradientView()
        .ignoresSafeArea()
}
```

- [ ] **Step 3: Build (verifies the .metal file is picked up by the synchronized folder)**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|metal|BUILD"`
Expected: `** BUILD SUCCEEDED **`, a `CompileMetalFile`/metallib step visible. If the `.metal` file is NOT compiled (no metal step and shader missing at runtime), stop and add it to the target explicitly.

- [ ] **Step 4: Commit**

```bash
git add Palettes/Utilities/PaletteShaders.metal Palettes/Views/Components/Generation/LiquidGradientView.swift
git commit -m "feat: add liquid gradient Metal shader and wrapper view" -- Palettes/Utilities/PaletteShaders.metal Palettes/Views/Components/Generation/LiquidGradientView.swift
```

---

### Task 2: GenerationOrbView

**Files:**
- Create: `Palettes/Views/Components/Generation/GenerationOrbView.swift`

**Interfaces:**
- Consumes: `LiquidGradientView(speed:intensity:)` (Task 1).
- Produces: `GenerationOrbView(statusText: String)` (used by Task 3).

- [ ] **Step 1: Create the file**

```swift
//
//  GenerationOrbView.swift
//  Palettes
//

import SwiftUI

/// Full-screen Siri-style waiting stage: liquid glass orb with a rotating
/// iridescent rim over a soft shader gradient.
struct GenerationOrbView: View {
    let statusText: String

    @State private var breathe = false
    private let startDate = Date()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea()

            LiquidGradientView(speed: 0.6, intensity: 0.45)
                .blur(radius: 70)
                .ignoresSafeArea()

            orb
        }
    }

    // MARK: - Orb

    private var orb: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)

            ZStack {
                // Soft halo lifting the orb off the gradient
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(.systemBackground).opacity(0.9), .clear],
                            center: .center, startRadius: 60, endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)

                chromaticRim(rotation: t * 40)

                // Glass body
                Circle()
                    .fill(Color(.systemBackground).opacity(0.55))
                    .frame(width: 320, height: 320)
                    .glassEffect(.regular, in: .circle)

                VStack(spacing: 28) {
                    Text(statusText)
                        .font(.system(size: 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 44)

                    shimmerBar(time: t)
                }
                .frame(width: 320)
            }
            .scaleEffect(breathe ? 1.04 : 0.98)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }

    // MARK: - Chromatic Rim

    private func chromaticRim(rotation: Double) -> some View {
        let rainbow: [Color] = [.cyan, .blue, .purple, .pink, .orange, .yellow, .cyan]
        return Circle()
            .strokeBorder(
                AngularGradient(colors: rainbow, center: .center),
                lineWidth: 10
            )
            .frame(width: 324, height: 324)
            .blur(radius: 9)
            .mask {
                ZStack {
                    Circle()
                        .trim(from: 0.02, to: 0.30)
                        .stroke(style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    Circle()
                        .trim(from: 0.52, to: 0.74)
                        .stroke(style: StrokeStyle(lineWidth: 22, lineCap: .round))
                }
                .frame(width: 324, height: 324)
            }
            .rotationEffect(.degrees(rotation))
    }

    // MARK: - Shimmer

    private func shimmerBar(time: Double) -> some View {
        let phase = time.truncatingRemainder(dividingBy: 1.6) / 1.6
        return Capsule()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 120, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.2), .blue, .blue.opacity(0.2)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 48, height: 5)
                    .offset(x: phase * 110 - 20)
            }
            .clipShape(Capsule())
    }
}

#Preview {
    GenerationOrbView(statusText: "Pastel summer landscape")
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Palettes/Views/Components/Generation/GenerationOrbView.swift
git commit -m "feat: add shader-driven generation waiting orb" -- Palettes/Views/Components/Generation/GenerationOrbView.swift
```

---

### Task 3: GenerationExperienceView

**Files:**
- Create: `Palettes/Views/Components/Generation/GenerationExperienceView.swift`

**Interfaces:**
- Consumes: `GenerationOrbView(statusText:)` (Task 2), `LiquidGradientView` (Task 1), `AppData.palettes`, `ToastManager.shared.show(_:icon:)`, `PaletteViewModel`.
- Produces: `GenerationExperienceView(statusText: String, generate: () async throws -> PaletteViewModel)` (used by Task 4).

- [ ] **Step 1: Create the file**

```swift
//
//  GenerationExperienceView.swift
//  Palettes
//

import SwiftUI

/// Full-screen generation session presented as a cover: the waiting orb morphs
/// into the result stage; Regenerate morphs back.
struct GenerationExperienceView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    let statusText: String
    let generate: () async throws -> PaletteViewModel

    @State private var palette: PaletteViewModel?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea()

            if let palette {
                resultStage(palette)
                    .transition(.blurReplace)
            } else {
                GenerationOrbView(statusText: statusText)
                    .transition(.blurReplace)
            }
        }
        .task {
            if palette == nil { await run() }
        }
    }

    // MARK: - Generation

    private func run() async {
        do {
            let result = try await generate()
            withAnimation(.smooth(duration: 0.7)) { palette = result }
        } catch {
            ToastManager.shared.show(error.localizedDescription, icon: "exclamationmark.triangle.fill")
            dismiss()
        }
    }

    private func regenerate() {
        withAnimation(.smooth(duration: 0.5)) { palette = nil }
        Task { await run() }
    }

    private func save() {
        guard let palette else { return }
        appData.palettes.append(palette)
        ToastManager.shared.show("Palette saved", icon: "checkmark.circle.fill")
        dismiss()
    }

    // MARK: - Result Stage

    private func resultStage(_ palette: PaletteViewModel) -> some View {
        ZStack(alignment: .top) {
            LiquidGradientView(speed: 0.35, intensity: 0.22)
                .blur(radius: 80)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Text(palette.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .padding(.top, 72)

                    swatchStrip(palette)
                    colorList(palette)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }

            header
        }
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)

            Spacer()
        }
        .padding(.horizontal)
    }

    private func swatchStrip(_ palette: PaletteViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<palette.colors.count, id: \.self) { i in
                Rectangle().fill(palette.colors[i])
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func colorList(_ palette: PaletteViewModel) -> some View {
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
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }
        }
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    regenerate()
                } label: {
                    Label("Regenerate", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

#Preview {
    GenerationExperienceView(
        statusText: "Warm autumn forest",
        generate: {
            try await Task.sleep(for: .seconds(3))
            return PaletteViewModel(
                name: "Warm Autumn Forest",
                colors: [Color(hex: "A95F4D")!, Color(hex: "D98A6C")!, Color(hex: "F5C79A")!, Color(hex: "E29C88")!],
                hexCodes: ["#A95F4D", "#D98A6C", "#F5C79A", "#E29C88"],
                colorNames: ["Amber", "Maple", "Goldenrod", "Moss"]
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
git add Palettes/Views/Components/Generation/GenerationExperienceView.swift
git commit -m "feat: add full-screen liquid glass generation experience" -- Palettes/Views/Components/Generation/GenerationExperienceView.swift
```

---

### Task 4: Rewire + restyle GenerateView, delete GeneratedPaletteSheet

**Files:**
- Modify: `Palettes/Views/Color/GenerateView.swift`
- Delete: `Palettes/Views/Components/GeneratedPaletteSheet.swift`

**Interfaces:**
- Consumes: `GenerationExperienceView(statusText:generate:)` (Task 3). Keeps `performGeneration() async throws -> PaletteViewModel` (already exists, unchanged).

- [ ] **Step 1: Replace state and presentation**

Remove these two state vars:

```swift
    @State private var isGenerating = false
    @State private var generatedPalette: PaletteViewModel?
```

Add:

```swift
    @State private var showGenerationExperience = false
```

Replace the `.sheet(item:)` modifier (after the NavigationStack closing brace) with:

```swift
        .fullScreenCover(isPresented: $showGenerationExperience) {
            GenerationExperienceView(statusText: generationStatusText, generate: performGeneration)
                .environmentObject(appData)
        }
```

Add the helper alongside `hasInput`:

```swift
    private var generationStatusText: String {
        let vibe = vibeDescription.trimmingCharacters(in: .whitespaces)
        return vibe.isEmpty ? "Generating palette…" : vibe
    }
```

In `generateContent`, remove `.disabled(isGenerating)`.

- [ ] **Step 2: Simplify the send button and remove startGeneration**

In `vibeTextField`, replace the send Button block with:

```swift
            if hasInput {
                Button {
                    showGenerationExperience = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(glowGradient)
                }
                .transition(.scale.combined(with: .opacity))
            }
```

Delete the whole `startGeneration()` function (keep `performGeneration()`).

- [ ] **Step 3: Glass restyle of the controls**

In `vibeInputSection`, wrap the HStack in a `GlassEffectContainer`:

```swift
    private var vibeInputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = selectedImage {
                imageChip(image)
            }
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 10) {
                    vibeTextField
                    imageMenuButton
                }
            }
        }
        .padding(.horizontal)
    }
```

In `vibeTextField`, replace:

```swift
        .background(.thinMaterial)
        .clipShape(Capsule())
```

with:

```swift
        .glassEffect(.regular.interactive(), in: .capsule)
```

In `imageChip`, replace:

```swift
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
```

with:

```swift
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
```

In `imageMenuButton`, delete the `if #available(iOS 26.0, *)` / `else` branching and keep only (label content of the Menu):

```swift
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
                .frame(width: 44, height: 44)
                .foregroundColor(.accentColor)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
```

In `paletteSizeSection`, wrap the slider block in a glass card — replace the outer `VStack(alignment: .leading, spacing: 8) { ... }.padding(.horizontal)` body so the slider VStack gains:

```swift
            VStack(spacing: 4) {
                Slider(value: $paletteSize, in: 2...12, step: 2)
                    .tint(.accentColor)

                HStack {
                    ForEach([2, 4, 6, 8, 10, 12], id: \.self) { value in
                        Text("\(value)")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Int(paletteSize) == value ? .primary : .tertiary)
                        if value < 12 { Spacer() }
                    }
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
```

In `colorsSection`'s row styling, replace:

```swift
                        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
```

with:

```swift
                        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
```

Soften the blob background: in `animatedBackground`, change `color.opacity(0.2)` to `color.opacity(0.12)`.

- [ ] **Step 4: Delete the retired sheet**

```bash
git rm Palettes/Views/Components/GeneratedPaletteSheet.swift
```

- [ ] **Step 5: Build**

Run: `xcodebuild -scheme Palettes -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Palettes/Views/Color/GenerateView.swift
git commit -m "feat: liquid glass Generate controls, full-screen generation cover" -- Palettes/Views/Color/GenerateView.swift Palettes/Views/Components/GeneratedPaletteSheet.swift
```

---

### Task 5: Visual verification

**Files:** none (verification only; temporary AUTOGEN hook added and reverted)

- [ ] **Step 1: Add temporary auto-run hook**

In `GenerateView`'s `.onAppear`, temporarily add at the top:

```swift
                if ProcessInfo.processInfo.environment["AUTOGEN"] == "1", !showGenerationExperience {
                    vibeDescription = "pastel summer landscape"
                    showGenerationExperience = true
                }
```

- [ ] **Step 2: Build for booted simulator, install, launch with AUTOGEN, screenshot orb quickly (2s) and result (25s)**

```bash
SCRATCH=<scratchpad>
xcodebuild -scheme Palettes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath $SCRATCH/dd build
xcrun simctl terminate booted com.halilbagosi.Palettes; xcrun simctl install booted "$(find $SCRATCH/dd/Build/Products -name Palettes.app | head -1)"
SIMCTL_CHILD_AUTOGEN=1 xcrun simctl launch booted com.halilbagosi.Palettes
sleep 3 && xcrun simctl io booted screenshot $SCRATCH/orb.png
sleep 22 && xcrun simctl io booted screenshot $SCRATCH/result.png
```

Expected: `orb.png` shows the glass orb with iridescent rim, vibe text, shimmer bar over a soft animated gradient. `result.png` shows the glass result stage with Save/Regenerate.

- [ ] **Step 3: Revert the AUTOGEN hook, rebuild, reinstall clean build**

Remove the hook added in Step 1. Then:

Run: `xcodebuild -scheme Palettes -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath $SCRATCH/dd build 2>&1 | grep -E "error:|BUILD"` and reinstall.
Expected: `** BUILD SUCCEEDED **`; `git status` shows `GenerateView.swift` clean vs HEAD.

- [ ] **Step 4: Check the Generate tab controls screenshot (no AUTOGEN)**

```bash
xcrun simctl launch booted com.halilbagosi.Palettes && sleep 3
xcrun simctl io booted screenshot $SCRATCH/controls.png
```

Expected: glass capsule input, glass cards for size/colors sections. (Navigate to Generate tab happens via the temporary default-tab trick only if needed; otherwise inspect manually.)
