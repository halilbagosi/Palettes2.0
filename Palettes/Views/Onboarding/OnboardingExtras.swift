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

    /// One of the phrases in `PalettesShortcuts` ("Generate a palette in ...").
    static func siriPhrase(appName: String) -> String {
        "Generate a palette in \(appName)"
    }
}

extension View {
    /// Hook for `PaletteDetailView`; inert unless the coach mark armed it.
    func onboardingExtras(for palette: PaletteViewModel) -> some View {
        modifier(OnboardingExtrasModifier(palette: palette))
    }
}

private struct OnboardingExtrasModifier: ViewModifier {
    let palette: PaletteViewModel

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
            .onAppear { arm() }
            .onDisappear { task?.cancel() }
    }

    private func arm() {
        guard OnboardingExtrasLogic.shouldPresent(
            target: appData.extrasPaletteID, paletteID: palette.id, alreadyShown: didShow) else { return }
        task?.cancel()
        task = Task {
            // Let the hint (and a color menu, if that's how it was dismissed) clear first.
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled,
                  OnboardingExtrasLogic.shouldPresent(
                    target: appData.extrasPaletteID, paletteID: palette.id, alreadyShown: didShow)
            else { return }
            didShow = true
            appData.extrasPaletteID = nil
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

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Palettes"
    }

    private var siriAvailable: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("A few things to try")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(OnboardingExtrasLogic.cards(siriAvailable: siriAvailable), id: \.self) { card in
                        view(for: card)
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 12)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            image = renderImage()
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        .sheet(isPresented: $isExporting) {
            ExportPaletteSheet(palette: palette)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func view(for card: OnboardingExtrasCard) -> some View {
        switch card {
        case .share: shareCard
        case .siri: siriCard
        case .widget: widgetCard
        case .icloud: icloudCard
        }
    }

    private func renderImage() -> UIImage? {
        let colorVMs = palette.paletteColors.map { pc in
            appData.colors.first { $0.HEX.caseInsensitiveCompare(pc.hex) == .orderedSame }
                ?? ColorViewModel(name: pc.name, color: pc.color, HEX: pc.hex, usedInPalette: true)
        }
        return PaletteImageRenderer.renderImage(for: palette, colors: colorVMs)
    }

    // MARK: - Cards

    private var shareCard: some View {
        ExtrasCard(title: "Share your palette", symbol: "square.and.arrow.up") {
            Text("Send it as an image, or export it as CSS, Swift and more.")
                .foregroundStyle(.secondary)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Preview of the \(palette.name) palette image")
            }
            Button {
                isExporting = true
            } label: {
                Label("Export or share", systemImage: "square.and.arrow.up.on.square")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .glassCapsuleButton()
        }
    }

    @ViewBuilder
    private var siriCard: some View {
        if #available(iOS 26.0, *) {
            ExtrasCard(title: "Ask Siri", symbol: "waveform") {
                Text("Say \u{201C}\(OnboardingExtrasLogic.siriPhrase(appName: appName))\u{201D}.")
                    .font(.body.weight(.medium))
                Text("Your palettes also show up in Spotlight search.")
                    .foregroundStyle(.secondary)
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
            }
        }
    }

    private var widgetCard: some View {
        ExtrasCard(title: "Home Screen widget", symbol: "square.grid.2x2") {
            Text("Keep a palette on your Home Screen with the Palettes widget.")
                .foregroundStyle(.secondary)
        }
    }

    private var icloudCard: some View {
        ExtrasCard(title: "iCloud", symbol: "icloud") {
            Text("Your palettes sync across your devices with iCloud.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct ExtrasCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}
