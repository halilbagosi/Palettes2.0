//
//  OnboardingExtras.swift
//  Palettes
//
//  Optional closing cards shown once, as a sheet, shortly after the coach
//  mark is dismissed on the palette onboarding created. Share, Siri and
//  Spotlight are live; the widget and iCloud cards are written but hidden
//  until those features ship.
//

import SwiftUI
import AppIntents

enum OnboardingExtras {
    /// Flip when the widget ships.
    static let showsWidgetCard = false
    /// Flip when v1 ships with CloudKit enabled (entitlements are commented
    /// out until the paid developer membership exists).
    static let showsICloudCard = false
}

enum OnboardingExtrasCard: Equatable {
    case share, siri, widget, icloud
}

/// Pure show rules and card list, separate from the view for testing.
enum OnboardingExtrasLogic {
    /// Only for the palette whose coach mark was just dismissed, and only once ever.
    static func shouldPresent(target: UUID?, paletteID: UUID, alreadyShown: Bool) -> Bool {
        !alreadyShown && target == paletteID
    }

    /// `siriAvailable` is false before iOS 26: the app's shortcuts and
    /// Spotlight donations only exist there, so the card would promise nothing.
    static func cards(
        siriAvailable: Bool,
        showsWidget: Bool = OnboardingExtras.showsWidgetCard,
        showsICloud: Bool = OnboardingExtras.showsICloudCard
    ) -> [OnboardingExtrasCard] {
        var cards: [OnboardingExtrasCard] = [.share]
        if siriAvailable { cards.append(.siri) }
        if showsWidget { cards.append(.widget) }
        if showsICloud { cards.append(.icloud) }
        return cards
    }

    /// The timer runs only while nothing else is on screen over the detail
    /// (color menu, Tag, edit, export, alert).
    static func shouldStartTimer(target: UUID?, paletteID: UUID, alreadyShown: Bool, isBusy: Bool) -> Bool {
        !isBusy && shouldPresent(target: target, paletteID: paletteID, alreadyShown: alreadyShown)
    }

    /// A phrase that exists in `PalettesShortcuts` and works on this device.
    /// "Generate a palette" throws without Apple Intelligence, so without AI
    /// the Open Palette phrase is used instead.
    static func siriPhrase(appName: String, usesAI: Bool, paletteName: String) -> String {
        usesAI ? "Generate a palette in \(appName)" : "Open \(paletteName) in \(appName)"
    }

    static func icloudLine(signedIn: Bool) -> String {
        signedIn
            ? "Your palettes sync across your devices with iCloud."
            : "Sign in to iCloud in Settings to sync your palettes across your devices."
    }
}

extension View {
    /// Hook for `PaletteDetailView`; inert unless the coach mark armed it.
    func onboardingExtras(for palette: PaletteViewModel, isBusy: Bool) -> some View {
        modifier(OnboardingExtrasModifier(palette: palette, isBusy: isBusy))
    }
}

private struct OnboardingExtrasModifier: ViewModifier {
    let palette: PaletteViewModel
    let isBusy: Bool

    @EnvironmentObject private var appData: AppData
    @AppStorage(OnboardingKeys.didShowExtras) private var didShow = false
    @State private var showSheet = false
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                OnboardingExtrasView(palette: palette)
                    .environmentObject(appData)
            }
            .onChange(of: appData.extrasPaletteID) { _, _ in arm() }
            // Anything opening over the detail stops the wait; closing restarts it.
            .onChange(of: isBusy) { _, _ in
                task?.cancel()
                arm()
            }
            .onAppear { arm() }
            .onDisappear {
                task?.cancel()
                showSheet = false
            }
    }

    private func arm() {
        guard OnboardingExtrasLogic.shouldStartTimer(
            target: appData.extrasPaletteID, paletteID: palette.id, alreadyShown: didShow, isBusy: isBusy)
        else { return }
        task?.cancel()
        task = Task {
            // Just long enough for the color menu to finish closing.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled,
                  OnboardingExtrasLogic.shouldStartTimer(
                    target: appData.extrasPaletteID, paletteID: palette.id, alreadyShown: didShow, isBusy: isBusy)
            else { return }
            // `didShow` is set by the sheet itself once it actually appears.
            showSheet = true
        }
    }
}

struct OnboardingExtrasView: View {
    let palette: PaletteViewModel

    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var image: UIImage?
    @State private var isExporting = false
    @State private var appeared = false
    @AppStorage(OnboardingKeys.didShowExtras) private var didShow = false
    @AccessibilityFocusState private var titleFocused: Bool

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Palettes"
    }

    private var siriAvailable: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    private var cards: [OnboardingExtrasCard] {
        OnboardingExtrasLogic.cards(siriAvailable: siriAvailable)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                        .reveal(appeared, index: 0, reduceMotion: reduceMotion)
                    VStack(spacing: 14) {
                        ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                            view(for: card, index: index)
                                .reveal(appeared, index: index + 1, reduceMotion: reduceMotion)
                        }
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(alignment: .top) {
                PaletteWash(colors: palette.colors)
                    .opacity(appeared ? 1 : 0)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                OnboardingPrimaryButton(title: "Start creating", systemImage: "arrow.right") {
                    // Back to the library, which then shows its options.
                    appData.activeTab = .palettes
                    appData.libraryOptionsTourPending = true
                    dismiss()
                }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
                    .reveal(appeared, index: cards.count + 1, reduceMotion: reduceMotion)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Counted as shown only once it is really on screen.
            didShow = true
            appData.extrasPaletteID = nil
            titleFocused = true
            image = renderImage()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .sheet(isPresented: $isExporting) {
            ExportPaletteSheet(palette: palette)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header

    /// The palette's own colors as a fanned row of drops over the closing
    /// line, in the same rounded voice as the onboarding steps.
    private var header: some View {
        VStack(spacing: 16) {
            SwatchFan(colors: palette.colors)
                .accessibilityHidden(true)
            VStack(spacing: 14) {
                OnboardingEyebrow(title: "You\u{2019}re all set", systemImage: "checkmark.seal.fill")
                OnboardingStepText(
                    title: "What else you can do",
                    subtitle: "\(palette.name) is saved. A few ways to take it further."
                )
                .accessibilityFocused($titleFocused)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func view(for card: OnboardingExtrasCard, index: Int) -> some View {
        let tint = tileColor(index)
        switch card {
        case .share: shareCard(tint: tint)
        case .siri: siriCard(tint: tint)
        case .widget: widgetCard(tint: tint)
        case .icloud: icloudCard(tint: tint)
        }
    }

    /// Each card's icon tile takes a color from the palette, in order.
    private func tileColor(_ index: Int) -> Color {
        let colors = palette.colors
        guard !colors.isEmpty else { return .accentColor }
        return colors[index % colors.count]
    }

    private func renderImage() -> UIImage? {
        let colorVMs = palette.paletteColors.map { pc in
            appData.colors.first { $0.HEX.caseInsensitiveCompare(pc.hex) == .orderedSame }
                ?? ColorViewModel(name: pc.name, color: pc.color, HEX: pc.hex, usedInPalette: true)
        }
        return PaletteImageRenderer.renderImage(for: palette, colors: colorVMs)
    }

    // MARK: - Cards

    private func shareCard(tint: Color) -> some View {
        ExtrasCard(title: "Share your palette", symbol: "square.and.arrow.up", tint: tint,
                   caption: "Send it as an image, or export it as CSS, Swift and more.") {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                    .accessibilityLabel("Preview of the \(palette.name) palette image")
            }
            Button {
                isExporting = true
            } label: {
                Label("Export or share", systemImage: "square.and.arrow.up.on.square")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .glassCapsuleButton()
        }
    }

    @ViewBuilder
    private func siriCard(tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            ExtrasCard(title: "Ask Siri", symbol: "waveform", tint: tint,
                       caption: "Your palettes also show up in Spotlight search.") {
                SiriPhraseBubble(phrase: OnboardingExtrasLogic.siriPhrase(
                    appName: appName, usesAI: OnboardingPaletteMaker.usesAI, paletteName: palette.name))
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
            }
        }
    }

    private func widgetCard(tint: Color) -> some View {
        ExtrasCard(title: "Home Screen widget", symbol: "square.grid.2x2", tint: tint,
                   caption: "Keep a palette on your Home Screen with the Palettes widget.") {
            EmptyView()
        }
    }

    private func icloudCard(tint: Color) -> some View {
        ExtrasCard(title: "iCloud", symbol: "icloud", tint: tint,
                   caption: OnboardingExtrasLogic.icloudLine(signedIn: FileManager.default.ubiquityIdentityToken != nil)) {
            EmptyView()
        }
    }
}

// MARK: - Pieces

private extension View {
    /// Rises and fades in after the ones before it.
    func reveal(_ shown: Bool, index: Int, reduceMotion: Bool) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.25)
                    : .spring(response: 0.55, dampingFraction: 0.85).delay(0.12 + Double(index) * 0.07),
                value: shown
            )
    }
}

/// A soft glow of the palette's colors bleeding down from the top of the
/// sheet, so it carries the palette that was just made.
private struct PaletteWash: View {
    var colors: [Color]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                ForEach(Array(colors.prefix(5).enumerated()), id: \.offset) { index, color in
                    let count = max(min(colors.count, 5), 1)
                    Circle()
                        .fill(color)
                        .frame(width: width * 0.62, height: width * 0.62)
                        .position(x: width * (CGFloat(index) + 0.5) / CGFloat(count),
                                  y: index.isMultiple(of: 2) ? -width * 0.08 : width * 0.04)
                }
            }
            .blur(radius: 60)
            .opacity(colorScheme == .dark ? 0.32 : 0.4)
            .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
        }
        .frame(height: 360)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The palette's colors as overlapping drops, fanned out from the middle.
private struct SwatchFan: View {
    var colors: [Color]

    var body: some View {
        let shown = Array(colors.prefix(6))
        HStack(spacing: -14) {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, color in
                let middle = Double(shown.count - 1) / 2
                let off = Double(index) - middle
                Circle()
                    .fill(color)
                    .frame(width: 46, height: 46)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                    .shadow(color: .black.opacity(0.14), radius: 6, y: 3)
                    .offset(y: CGFloat(abs(off)) * 4)
                    .zIndex(-abs(off))
            }
        }
        .padding(.vertical, 4)
    }
}

/// What to say to Siri, as a speech bubble.
private struct SiriPhraseBubble: View {
    var phrase: String

    var body: some View {
        Text("\u{201C}\(phrase)\u{201D}")
            .font(.system(.body, design: .rounded).weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.accentColor.opacity(0.12),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 18, bottomLeadingRadius: 6,
                    bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous)
            )
            .accessibilityLabel("Say: \(phrase)")
    }
}

private struct ExtrasCard<Content: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    let caption: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(GenerationResultView.ink(on: tint))
                    .frame(width: 44, height: 44)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .accessibilityAddTraits(.isHeader)
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            content
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
