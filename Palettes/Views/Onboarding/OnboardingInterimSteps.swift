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
    @Published private(set) var samplePoint = OnboardingSampling.center
    @Published private(set) var sampleCount = 0
    @Published private(set) var genState = GenState.generating
    @Published private(set) var genColors: [Color] = []
    @Published var isSaving = false

    private var sampler: ImageColorExtractor.PixelSampler?
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

    func beginAdjust() {
        guard let image = model.capturedImage else { return }
        sampler = ImageColorExtractor.PixelSampler(image: image)
        model.brightness = 0.5
        model.saturation = 0.5
        samplePoint = OnboardingSampling.center
        model.scannedRGB = rgb(at: samplePoint, in: image)
    }

    private func rgb(at point: CGPoint, in image: UIImage) -> (r: Double, g: Double, b: Double) {
        sampler?.color(at: point, radius: 2) ?? ImageColorExtractor.sampleColor(from: image, at: point, radius: 2)
    }

    /// `point` is in the orb window's coordinates.
    func resample(tap point: CGPoint, windowDiameter: CGFloat) {
        guard let image = model.capturedImage,
              let normalized = OnboardingSampling.normalizedPoint(
                forTap: point, imageSize: image.size, diameter: windowDiameter) else { return }
        resample(to: normalized)
    }

    func resample(to normalized: CGPoint) {
        guard model.step == .adjust, let image = model.capturedImage else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            samplePoint = normalized
            model.scannedRGB = rgb(at: normalized, in: image)
        }
        sampleCount += 1
        UIAccessibility.post(notification: .announcement, argument: "Selected \(adjustedName)")
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
    func adjustContent(onGenerate: @escaping () -> Void) -> OnboardingStepContent {
        OnboardingStepContent(
            key: "adjust",
            title: nil,
            subtitle: nil,
            body: AnyView(AdjustInterimBody(flow: self, model: model)),
            primary: .init(title: "Generate palette", systemImage: "sparkles", action: onGenerate)
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
            return OnboardingStepContent(key: "gen-wait", title: "Mixing your palette", subtitle: "Pulling colors out of yours.", primary: nil)
        case .ready(let made):
            return OnboardingStepContent(
                key: "gen-ready",
                title: nil,
                subtitle: nil,
                body: AnyView(ReadyInterimBody(made: made)),
                primary: .init(title: "See my palette", systemImage: "arrow.right", isEnabled: !isSaving) { open(made) }
            )
        case .failed:
            return OnboardingStepContent(
                key: "gen-failed",
                title: "Couldn't make a palette",
                subtitle: "Something went wrong. Give it another try.",
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
                    .font(.title2.weight(.bold))
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

private struct ReadyInterimBody: View {
    let made: OnboardingPaletteMaker.Made

    var body: some View {
        VStack(spacing: 20) {
            OnboardingPaletteName(name: made.palette.name, usesGradient: made.usedAI)
            HStack(spacing: 12) {
                ForEach(made.palette.paletteColors) { color in
                    Circle().fill(color.color)
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Palette colors")
            .accessibilityValue(made.palette.paletteColors.map { "\($0.name), \($0.hex)" }.joined(separator: "; "))
        }
    }
}
