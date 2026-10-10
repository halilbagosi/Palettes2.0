//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI

struct PaletteTabView: View {

    @ObservedObject private var appData = AppData.shared
    @StateObject private var replay = OnboardingReplayCoordinator()
    @StateObject private var router = SceneRouter()
    /// Per window, and restored with it. `appData.activeTab` only carries
    /// requests to switch, which every window follows.
    @SceneStorage("selectedTab") private var selectedTab: TabValue = .palettes
    @AppStorage(OnboardingKeys.didComplete) private var didCompleteOnboarding = false
    /// DEBUG `-onboardingStart` presents onboarding regardless of the flag, once.
    @State private var debugOnboardingFinished = false
    /// What the cover is actually bound to. It follows `showsOnboarding`, but
    /// a replay is presented a beat later: on iOS 17 a cover asked for while
    /// the Settings sheet is still finishing its dismissal is silently
    /// dropped, and with a constant binding SwiftUI never asks again.
    @State private var isOnboardingPresented = false
    @State private var presentTask: Task<Void, Never>?

    private var showsOnboarding: Bool {
        OnboardingDebug.isLaunchArgument ? !debugOnboardingFinished : !didCompleteOnboarding
    }

    /// Read from the store rather than the `@AppStorage` copy, which can lag
    /// a write made elsewhere (the Settings replay resets the flag directly).
    private var onboardingWanted: Bool {
        OnboardingDebug.isLaunchArgument
            ? !debugOnboardingFinished
            : !UserDefaults.standard.bool(forKey: OnboardingKeys.didComplete)
    }

    init() {
        // First launch: the cover is up from the first frame, no flash of the tabs.
        _isOnboardingPresented = State(initialValue: OnboardingDebug.isLaunchArgument
            || !UserDefaults.standard.bool(forKey: OnboardingKeys.didComplete))
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
        .onAppear {
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
            OnboardingView { reason in
                if case .completed(let id) = reason {
                    // PaletteView pushes the detail under the cover, so it is
                    // already in place when the cover finishes dismissing.
                    selectedTab = .palettes
                    appData.coachMarkPaletteID = id
                    appData.pendingOpenPaletteID = id
                }
                didCompleteOnboarding = true
                debugOnboardingFinished = true
            }
            .environmentObject(appData)
            .toastOverlay()
        }
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
            isOnboardingPresented = true
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
