//
//  SceneRouter.swift
//  Palettes
//
//  Per-window navigation state. `AppData` is shared by every window, so state
//  that belongs to one window (which tab is showing, which creation sheet is
//  up) lives here instead: on iPad two windows can show different tabs, and
//  menu-bar commands act on the window that has focus.
//
//  `AppData.activeTab` stays as the app-wide way to *ask* for a tab (intents,
//  onboarding, cross-tab buttons); each window follows those requests.
//

import SwiftUI

@MainActor
final class SceneRouter: ObservableObject {
    @Published var isCreatingPalette = false
    @Published var isCreatingColor = false
    @Published var isShowingSettings = false
}

/// What the menu bar and keyboard shortcuts can do in the focused window.
struct SceneCommands {
    var canGenerate: Bool
    var selectTab: (TabValue) -> Void
    var newPalette: () -> Void
    var newColor: () -> Void
    var showSettings: () -> Void
}

private struct SceneCommandsKey: FocusedValueKey {
    typealias Value = SceneCommands
}

private struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: TabValue = .palettes
}

extension FocusedValues {
    var sceneCommands: SceneCommands? {
        get { self[SceneCommandsKey.self] }
        set { self[SceneCommandsKey.self] = newValue }
    }
}

extension EnvironmentValues {
    /// The tab this window is showing. Tabs stay alive off screen, so views
    /// that should only act while visible (first-visit intros) check it.
    var selectedTab: TabValue {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}
