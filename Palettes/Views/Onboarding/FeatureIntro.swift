//
//  FeatureIntro.swift
//  Palettes
//
//  A one-time welcome sheet the first time each of the Colors, Search and
//  Generate tabs opens: the empty-state art, an eyebrow, a rounded title and
//  a few things the tab can do. It waits for the main onboarding to finish
//  and never comes back once shown (Settings' replay resets it).
//

import SwiftUI

enum FeatureIntro: String, CaseIterable {
    case colors, search, generate

    struct Point: Hashable {
        var symbol: String
        var title: String
        var text: String
    }

    var key: String {
        switch self {
        case .colors: OnboardingKeys.didIntroColors
        case .search: OnboardingKeys.didIntroSearch
        case .generate: OnboardingKeys.didIntroGenerate
        }
    }

    /// The tab this intro belongs to; it only ever shows while that tab is on screen.
    var tab: TabValue {
        switch self {
        case .colors: .colors
        case .search: .search
        case .generate: .generate
        }
    }

    var symbol: String {
        switch self {
        case .colors: "circle.grid.cross.fill"
        case .search: "magnifyingglass"
        case .generate: "sparkles"
        }
    }

    var eyebrow: String {
        switch self {
        case .colors: "Colors"
        case .search: "Search"
        case .generate: "Generate"
        }
    }

    var title: String {
        switch self {
        case .colors: "Every color you collect"
        case .search: "Find anything, fast"
        case .generate: "Palettes, imagined for you"
        }
    }

    var subtitle: String {
        switch self {
        case .colors: "Your library of single colors, ready to drop into any palette."
        case .search: "Look through your whole library at once."
        case .generate: "Apple Intelligence composes a palette from a few words, your colors or a photo."
        }
    }

    var points: [Point] {
        switch self {
        case .colors:
            [
                .init(symbol: "eyedropper", title: "Pick, scan or choose",
                      text: "Set a color by hand, scan it with the camera, or pull it from a photo."),
                .init(symbol: "hand.tap", title: "Press and hold a color",
                      text: "Copy it as HEX or RGB, export it for CSS, share or edit it."),
                .init(symbol: "line.3.horizontal.decrease.circle", title: "Make it yours",
                      text: "The \u{2022}\u{2022}\u{2022} menu switches to a compact grid and filters your colors."),
            ]
        case .search:
            [
                .init(symbol: "number", title: "Names and hex codes",
                      text: "Type a name or a hex code, with or without the #."),
                .init(symbol: "drop.halffull", title: "Browse by hue",
                      text: "Tap the hue chips to see only the reds, the blues, or both."),
                .init(symbol: "tag", title: "Filter by tag",
                      text: "Tags you give colors in a palette show up here as filters."),
            ]
        case .generate:
            [
                .init(symbol: "text.bubble", title: "Describe a vibe",
                      text: "\u{201C}Foggy harbor at dawn\u{201D} is all it needs."),
                .init(symbol: "circle.grid.cross", title: "Start from your colors or a photo",
                      text: "Choose colors from your library, or take or pick a photo."),
                .init(symbol: "slider.horizontal.3", title: "Shape the result",
                      text: "Pick a size and harmony, then ask for changes until it feels right."),
            ]
        }
    }
}

extension View {
    /// Shows `intro`'s welcome sheet the first time this view appears.
    func featureIntro(_ intro: FeatureIntro) -> some View {
        modifier(FeatureIntroModifier(intro: intro))
    }
}

private struct FeatureIntroModifier: ViewModifier {
    let intro: FeatureIntro

    @AppStorage private var didShow: Bool
    @AppStorage(OnboardingKeys.didComplete) private var onboardingDone = false
    @Environment(\.selectedTab) private var selectedTab
    @State private var showSheet = false
    @State private var task: Task<Void, Never>?

    init(intro: FeatureIntro) {
        self.intro = intro
        _didShow = AppStorage(wrappedValue: false, intro.key)
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                FeatureIntroSheet(intro: intro) { showSheet = false }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .onAppear { didShow = true }
            }
            .onAppear { arm() }
            .onChange(of: onboardingDone) { _, _ in arm() }
            // Tabs stay alive off screen (and some load before they're opened):
            // each intro waits for its own tab to be the one showing.
            .onChange(of: selectedTab) { _, _ in arm() }
            .onDisappear { task?.cancel() }
    }

    private var isEligible: Bool {
        onboardingDone && !didShow && selectedTab == intro.tab
    }

    private func arm() {
        task?.cancel()
        // A request that never got on screen (another sheet was up) must not
        // stay pending and block a later try.
        if showSheet, !didShow, selectedTab != intro.tab { showSheet = false }
        // Not over the main onboarding, only on its own tab, and only once.
        guard isEligible, !showSheet else { return }
        task = Task {
            // Let the tab settle in first.
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, isEligible else { return }
            showSheet = true
        }
    }
}

struct FeatureIntroSheet: View {
    let intro: FeatureIntro
    var onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                EmptyStateArt(symbol: intro.symbol, size: 104)
                    .padding(.top, 20)
                    .introReveal(appeared, index: 0, reduceMotion: reduceMotion)
                VStack(spacing: 14) {
                    OnboardingEyebrow(title: intro.eyebrow, systemImage: intro.symbol)
                    OnboardingStepText(title: intro.title, subtitle: intro.subtitle)
                        .accessibilityFocused($titleFocused)
                }
                .introReveal(appeared, index: 1, reduceMotion: reduceMotion)
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(intro.points.enumerated()), id: \.element) { index, point in
                        row(point, tint: EmptyStateArt.defaultHues[(index * 2 + intro.hueOffset) % EmptyStateArt.defaultHues.count])
                            .introReveal(appeared, index: index + 2, reduceMotion: reduceMotion)
                    }
                }
                .frame(maxWidth: 440)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            OnboardingPrimaryButton(title: "Got it", action: onDone)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .introReveal(appeared, index: intro.points.count + 2, reduceMotion: reduceMotion)
        }
        .onAppear {
            titleFocused = true
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
    }

    private func row(_ point: FeatureIntro.Point, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: point.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(GenerationResultView.ink(on: tint))
                .frame(width: 42, height: 42)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(point.title)
                    .font(.system(.headline, design: .rounded))
                Text(point.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension FeatureIntro {
    /// Each tab starts its icon tiles at a different hue.
    var hueOffset: Int {
        switch self {
        case .colors: 0
        case .search: 3
        case .generate: 4
        }
    }
}

private extension View {
    func introReveal(_ shown: Bool, index: Int, reduceMotion: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : .spring(response: 0.55, dampingFraction: 0.85).delay(0.08 + Double(index) * 0.06),
                value: shown
            )
    }
}
