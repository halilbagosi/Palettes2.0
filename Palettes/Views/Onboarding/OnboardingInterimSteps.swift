//
//  OnboardingInterimSteps.swift
//  Palettes
//
//  The adjust and generate steps, carried over from plan 014 onto the new
//  layout and orb so the flow works end to end. Plan 015 phases 2 and 3 replace
//  both (expanded picker and ColorRangeSlider; poured swatches).
//

import SwiftUI
import Combine

@MainActor
final class OnboardingInterimFlow: ObservableObject {
    enum GenState {
        case generating
        case ready(OnboardingPaletteMaker.Made)
        case failed
    }

    let model: OnboardingModel
    @Published private(set) var sampleCount = 0
    @Published private(set) var genState = GenState.generating
    @Published private(set) var genColors: [Color] = []
    @Published var isSaving = false

    private var sampler: ImageColorExtractor.PixelSampler?
    /// A color chosen in the full-screen picker, applied when the adjust step begins.
    private var pendingPick: (r: Double, g: Double, b: Double)?
    private var genTask: Task<Void, Never>?

    init(model: OnboardingModel) { self.model = model }

    var adjustedColor: Color {
        guard let rgb = model.adjustedRGB else { return .gray }
        return ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)
    }

    var adjustedName: String {
        guard let hex = model.selectedHex else { return "" }
        return ColorNamer.name(forHex: String(hex.dropFirst()))
    }

    func stop() { genTask?.cancel() }

    // MARK: Adjust

    /// The color the full-screen picker opens on: the middle of the frame.
    func suggestedRGB() -> (r: Double, g: Double, b: Double)? {
        guard let image = model.capturedImage else { return nil }
        if sampler == nil { sampler = ImageColorExtractor.PixelSampler(image: image) }
        return rgb(at: OnboardingSampling.center, in: image)
    }

    /// Records the full-screen picker's choice for `beginAdjust`.
    func usePicked(rgb: (r: Double, g: Double, b: Double)) {
        pendingPick = rgb
    }

    /// A color picked again from the adjust step: replaces the base, resets the sliders.
    func applyPicked(rgb: (r: Double, g: Double, b: Double)) {
        model.brightness = 0.5
        model.saturation = 0.5
        model.scannedRGB = rgb
        sampleCount += 1
        UIAccessibility.post(notification: .announcement, argument: "Selected \(adjustedName)")
    }

    func beginAdjust() {
        guard let image = model.capturedImage else { return }
        sampler = ImageColorExtractor.PixelSampler(image: image)
        model.brightness = 0.5
        model.saturation = 0.5
        if let pick = pendingPick {
            pendingPick = nil
            model.scannedRGB = pick
        } else {
            model.scannedRGB = rgb(at: OnboardingSampling.center, in: image)
        }
    }

    private func rgb(at point: CGPoint, in image: UIImage) -> (r: Double, g: Double, b: Double) {
        sampler?.color(at: point, radius: 2) ?? ImageColorExtractor.sampleColor(from: image, at: point, radius: 2)
    }

    // MARK: Generate

    func startGeneration(appData: AppData, reduceMotion: Bool) {
        guard let hex = model.selectedHex else { return }
        genTask?.cancel()
        genColors = [adjustedColor]
        withAnimation(.easeInOut(duration: 0.3)) { genState = .generating }
        let names = appData.palettes.map(\.name)
        let delay: Duration = reduceMotion ? .zero : .milliseconds(650)
        genTask = Task {
            do {
                let made = try await OnboardingPaletteMaker.make(
                    anchorHex: hex, existingNames: names, revealDelay: delay
                ) { colors in self.genColors = colors }
                guard !Task.isCancelled else { return }
                genColors = made.palette.colors
                withAnimation(.easeInOut(duration: 0.4)) { genState = .ready(made) }
                UIAccessibility.post(notification: .announcement,
                                     argument: "Palette ready: \(made.palette.name)")
            } catch is CancellationError {
                // Skipped or left the screen.
            } catch {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.3)) { genState = .failed }
            }
        }
    }
}

// MARK: - Content

extension OnboardingInterimFlow {
    func adjustContent(onGenerate: @escaping () -> Void, onRepick: @escaping () -> Void) -> OnboardingStepContent {
        OnboardingStepContent(
            key: "adjust",
            title: nil,
            subtitle: nil,
            body: AnyView(AdjustInterimBody(flow: self, model: model)),
            primary: .init(title: "Generate palette", systemImage: "sparkles", action: onGenerate),
            secondary: .button("Repick Color", onRepick)
        )
    }

    func generateContent(
        appData: AppData,
        retry: @escaping () -> Void,
        open: @escaping (OnboardingPaletteMaker.Made) -> Void,
        skip: @escaping () -> Void
    ) -> OnboardingStepContent {
        switch genState {
        case .generating:
            // Waiting and ready share one key and one body, so the swatch row
            // stays put and only the words change when the palette lands.
            return OnboardingStepContent(
                key: "gen",
                body: AnyView(GenerateInterimBody(flow: self)),
                primary: nil
            )
        case .ready(let made):
            return OnboardingStepContent(
                key: "gen",
                body: AnyView(GenerateInterimBody(flow: self)),
                primary: .init(title: "See my palette", systemImage: "arrow.right", isEnabled: !isSaving) { open(made) }
            )
        case .failed:
            return OnboardingStepContent(
                key: "gen-failed",
                title: "That didn\u{2019}t quite work",
                subtitle: "Something went wrong mixing your palette. Let\u{2019}s give it another go.",
                primary: .init(title: "Try again", systemImage: "arrow.clockwise", action: retry),
                secondary: .button("Skip for now", skip)
            )
        }
    }
}

private struct AdjustInterimBody: View {
    @ObservedObject var flow: OnboardingInterimFlow
    @ObservedObject var model: OnboardingModel

    private func label(_ value: Double) -> String {
        let percent = Int(((value - 0.5) * 200).rounded())
        return percent == 0 ? "Neutral" : String(format: "%+d%%", percent)
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text(flow.adjustedName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(model.selectedHex ?? "")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Selected color")
            .accessibilityValue("\(flow.adjustedName), \(model.selectedHex ?? "")")
            VStack(spacing: 14) {
                AdjustmentSlider(
                    title: "Brightness", valueLabel: label(model.brightness),
                    leftLabel: "Darker", rightLabel: "Brighter", value: $model.brightness)
                AdjustmentSlider(
                    title: "Saturation", valueLabel: label(model.saturation),
                    leftLabel: "Muted", rightLabel: "Vivid", value: $model.saturation)
            }
            .frame(maxWidth: 420)
        }
    }
}

/// The generate step, waiting and ready. The words above the swatches
/// cross-fade ("Mixing your palette" becomes the palette's name)
/// in a slot of fixed height, while the row below keeps filling in place.
private struct GenerateInterimBody: View {
    @ObservedObject var flow: OnboardingInterimFlow

    private var made: OnboardingPaletteMaker.Made? {
        if case .ready(let made) = flow.genState { return made }
        return nil
    }

    var body: some View {
        let made = self.made
        // Kept short (no eyebrow, smaller swatches) so the row sits well clear
        // of the pinned "See my palette" button.
        VStack(spacing: 18) {
            ZStack {
                if let made {
                    OnboardingPaletteName(name: made.palette.name, usesGradient: made.usedAI)
                        // Never taller than the waiting copy it replaces.
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .transition(.blurFade)
                } else {
                    OnboardingStepText(
                        title: "Mixing your palette",
                        subtitle: "Finding colors that go beautifully with yours."
                    )
                    .transition(.blurFade)
                }
            }
            // As tall as the waiting copy, so the row doesn't jump when
            // a shorter name replaces it.
            .frame(minHeight: 92)
            GenerationSwatchRow(colors: made?.palette.colors ?? flow.genColors,
                                expected: made?.palette.colors.count ?? OnboardingPaletteMaker.paletteSize,
                                maxSize: 46)
                .frame(maxWidth: 300)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Palette colors")
                .accessibilityValue(made.map { $0.palette.paletteColors.map { "\($0.name), \($0.hex)" }.joined(separator: "; ") } ?? "")
        }
        .animation(.easeInOut(duration: 0.5), value: made != nil)
    }
}
