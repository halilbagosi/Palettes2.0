//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI
import Combine

struct PaletteTabView: View {

    @ObservedObject private var appData = AppData.shared
    @StateObject private var replay = OnboardingReplayCoordinator()
    @StateObject private var router = SceneRouter()
    /// Per window, and restored with it. `appData.activeTab` only carries
    /// requests to switch, which every window follows.
    @SceneStorage("selectedTab") private var storedTab: TabValue = .palettes
    /// What the tab bar is bound to. Plain state rather than the scene
    /// storage directly: a scene-storage write lands a beat late, and the
    /// extra update selecting Search triggers (its search field) re-read the
    /// old tab, so the glass pill slid back before settling on Search.
    @State private var selectedTab: TabValue = .palettes
    @State private var restoredTab = false
    @AppStorage(OnboardingKeys.didComplete) private var didCompleteOnboarding = false
    /// What the cover is actually bound to. It follows `showsOnboarding`, but
    /// a replay is presented a beat later: on iOS 17 a cover asked for while
    /// the Settings sheet is still finishing its dismissal is silently
    /// dropped, and with a constant binding SwiftUI never asks again.
    @State private var isOnboardingPresented = false
    @State private var presentTask: Task<Void, Never>?

    private var showsOnboarding: Bool { !didCompleteOnboarding }

    /// Read from the store rather than the `@AppStorage` copy, which can lag
    /// a write made elsewhere (the Settings replay resets the flag directly).
    private var onboardingWanted: Bool {
        !UserDefaults.standard.bool(forKey: OnboardingKeys.didComplete)
    }


    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .environmentObject(appData)
        .environmentObject(replay)
        .environmentObject(router)
        .environment(\.selectedTab, selectedTab)
        .focusedSceneValue(\.sceneCommands, sceneCommands)
        .onReceive(appData.$activeTab.dropFirst()) { selectedTab = $0 }
        .onChange(of: selectedTab) { _, tab in storedTab = tab }
        .onReceive(QuickActionCenter.shared.$pending.compactMap { $0 }) { _ in
            // On a cold launch this fires during the first layout, when a tab
            // switch or sheet is dropped; wait for the window to settle.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                if let action = QuickActionCenter.shared.take() { perform(action) }
            }
        }
        .onOpenURL { url in
            guard let link = WidgetLink(url: url) else { return }
            // Same settle delay as quick actions: on a cold launch the URL
            // arrives during the first layout, when a tab switch is dropped.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                open(link)
            }
        }
        .onReceive(WidgetLinkInbox.shared.$pending.compactMap { $0 }) { _ in
            // A widget button or control (OpenLinkIntent). Same settle delay
            // as quick actions.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                if let link = WidgetLinkInbox.shared.take() { open(link) }
            }
        }
        .onAppear {
            if !restoredTab {
                restoredTab = true
                selectedTab = storedTab
            }
            // First launch: present on the first appearance, without animation
            // (a cover that starts out shown slides up, carrying the island's
            // black pill with it); it fades its content in instead.
            if onboardingWanted { presentOnboarding(after: .zero) }
            #if DEBUG
            if ScreenshotSeed.opensSettings {
                Task {
                    try? await Task.sleep(for: .milliseconds(900))
                    router.isShowingSettings = true
                }
            }
            #endif
            // A window restored onto Generate after Apple Intelligence went away.
            if selectedTab == .generate, !AppleIntelligence.isDeviceSupported {
                selectedTab = .palettes
            }
        }
        .sheet(isPresented: $router.isShowingSettings, onDismiss: {
            if replay.consume() { OnboardingKeys.resetForReplay() }
        }) {
            SettingsView()
                .environmentObject(appData)
                .environmentObject(replay)
        }
        // Attached after the environment objects so onboarding (and the views
        // it reuses) can read AppData. The only way out is `onFinish`.
        .fullScreenCover(isPresented: Binding(
            get: { isOnboardingPresented },
            // The only way out is `onFinish`; anything else re-presents it.
            set: { shown in
                isOnboardingPresented = shown
                if !shown, onboardingWanted { presentOnboarding(after: .milliseconds(300)) }
            }
        )) {
            OnboardingEntryView { reason in
                if case .completed(let id) = reason {
                    // PaletteView pushes the detail under the cover, so it is
                    // already in place when the cover finishes dismissing.
                    selectedTab = .palettes
                    appData.coachMarkPaletteID = id
                    appData.pendingOpenPaletteID = id
                }
                didCompleteOnboarding = true
            }
            .environmentObject(appData)
            .toastOverlay()
            // Faded in over the tabs rather than slid up: the slide would carry
            // the island's black pill up the screen with it.
            .modifier(FadeInOnAppear())
            .presentationBackground(.clear)
        }
        // Once onboarding is out of the way: "Sync with iCloud?", asked once.
        .iCloudSyncPrompt(appData: appData, isReady: !isOnboardingPresented && !router.isShowingSettings)
        // After a few saved palettes: the system's rating prompt, once per version.
        .reviewPrompt(paletteCount: appData.palettes.count, isReady: !isOnboardingPresented && !router.isShowingSettings)
        // Belt and braces for the replay: re-check whenever defaults change.
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            if onboardingWanted, !isOnboardingPresented {
                presentOnboarding(after: .milliseconds(450))
            }
        }
        .onChange(of: showsOnboarding) { _, shows in
            if shows {
                presentOnboarding(after: .milliseconds(450))
            } else {
                presentTask?.cancel()
                isOnboardingPresented = false
            }
        }
    }

    /// Presents the cover once whatever was on screen has fully gone.
    private func presentOnboarding(after delay: Duration) {
        presentTask?.cancel()
        presentTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, onboardingWanted else { return }
            // No slide-up: the cover fades its content in instead.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isOnboardingPresented = true }
        }
    }

    // MARK: - iOS 18+ (Tab builder, sidebar-adaptable, Liquid Glass chrome on 26)

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Palettes", systemImage: "swatchpalette.fill", value: TabValue.palettes) {
                PaletteView()
            }

            Tab("Colors", systemImage: "circle.grid.cross.fill", value: TabValue.colors) {
                ColorsView()
            }

            // AI generation relies on Apple Intelligence (iOS 26, eligible hardware).
            if #available(iOS 26.0, *), AppleIntelligence.isDeviceSupported {
                Tab("Generate", systemImage: "sparkles", value: TabValue.generate) {
                    GenerateView()
                }
            }

            Tab(value: TabValue.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarLiquidGlassChrome()
    }

    // MARK: - iOS 17 (classic tab bar; no Generate tab)

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            PaletteView()
                .tabItem { Label("Palettes", systemImage: "swatchpalette.fill") }
                .tag(TabValue.palettes)

            ColorsView()
                .tabItem { Label("Colors", systemImage: "circle.grid.cross.fill") }
                .tag(TabValue.colors)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(TabValue.search)
        }
    }

    /// A Home Screen quick action (see QuickActions.swift). Ignored until
    /// onboarding is done: its cover would hide whatever opened.
    private func perform(_ action: QuickAction) {
        guard !onboardingWanted else { return }
        afterClosingSheets {
            switch action {
            case .newPalette, .scanPalette:
                router.isScanRequested = action == .scanPalette
                selectedTab = .palettes
                router.isCreatingPalette = true
            case .newColor, .scanColor:
                router.isScanRequested = action == .scanColor
                selectedTab = .colors
                router.isCreatingColor = true
            case .generatePalette:
                if AppleIntelligence.isDeviceSupported { selectedTab = .generate }
            }
        }
    }

    /// A palettes:// link from a widget or control (see WidgetLink).
    /// Ids that no longer exist open the tab and nothing else.
    private func open(_ link: WidgetLink) {
        if let action = QuickAction(link) { return perform(action) }
        switch link {
        case .copyPalette(let id):
            guard let palette = appData.palettes.first(where: { $0.id == id }) else { return }
            copyToClipboard(WidgetCopyText.palette(palette.hexCodes), label: "Copied Palette")
        case .copyColor(let id):
            guard let color = appData.colors.first(where: { $0.id == id }) else { return }
            copyToClipboard(WidgetCopyText.color(color.HEX), label: "Copied HEX")
        case .palette(let id):
            guard !onboardingWanted else { return }
            afterClosingSheets {
                selectedTab = .palettes
                if appData.palettes.contains(where: { $0.id == id }) { appData.pendingOpenPaletteID = id }
            }
        case .color(let id):
            guard !onboardingWanted else { return }
            afterClosingSheets {
                selectedTab = .colors
                if appData.colors.contains(where: { $0.id == id }) { appData.pendingOpenColorID = id }
            }
        case .library:
            guard !onboardingWanted else { return }
            afterClosingSheets { selectedTab = .palettes }
        case .newPalette, .newColor, .scanColor, .scanPalette:
            break // QuickAction above
        }
    }

    /// Start from the library, not on top of a sheet already up: close
    /// Settings or a creation sheet, and run `body` once it has gone.
    private func afterClosingSheets(_ body: @escaping () -> Void) {
        let sheetWasUp = router.isShowingSettings || router.isCreatingPalette || router.isCreatingColor
        router.isShowingSettings = false
        router.isCreatingPalette = false
        router.isCreatingColor = false
        router.isScanRequested = false
        guard sheetWasUp else { return body() }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            body()
        }
    }

    /// What the menu bar's commands do in this window (see `PalettesCommands`).
    private var sceneCommands: SceneCommands {
        SceneCommands(
            canGenerate: AppleIntelligence.isDeviceSupported,
            selectTab: { tab in selectedTab = tab },
            newPalette: {
                selectedTab = .palettes
                router.isCreatingPalette = true
            },
            newColor: {
                selectedTab = .colors
                router.isCreatingColor = true
            },
            showSettings: { router.isShowingSettings = true }
        )
    }
}

enum TabValue: String {
    case palettes, colors, search, generate
}

extension View {
    /// iOS 26 tab-bar Liquid Glass chrome; a no-op on earlier systems.
    @ViewBuilder
    func tabBarLiquidGlassChrome() -> some View {
        if #available(iOS 26.0, *) {
            self
                .tabBarMinimizeBehavior(.onScrollDown)
                .scrollEdgeEffectHidden(false, for: .all)
                .softScrollEdge()
        } else {
            self
        }
    }
}

#Preview {
    PaletteTabView()
}

/// Fades its content in once it appears. Onboarding's cover is presented
/// without animation and uses this instead of the slide-up.
private struct FadeInOnAppear: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.easeOut(duration: 0.35)) { shown = true } }
    }
}
