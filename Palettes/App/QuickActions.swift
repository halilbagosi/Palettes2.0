//
//  QuickActions.swift
//  Palettes
//
//  Home Screen quick actions (long-press the app icon). The scene delegate
//  hands each one to `QuickActionCenter`; the first library window to see it
//  (see PaletteTabView) takes it and opens the matching sheet or tab.
//
//  Scan Color opens New Color and then the camera (the photo library where
//  there's no camera), through `consumeScanRequest`.
//

import Combine
import SwiftUI
import UIKit

enum QuickAction: String, CaseIterable {
    case newPalette, newColor, scanColor, generatePalette

    private static let typePrefix = "com.halilbagosi.palettes.quickaction."

    init?(_ item: UIApplicationShortcutItem) {
        guard item.type.hasPrefix(Self.typePrefix) else { return nil }
        self.init(rawValue: String(item.type.dropFirst(Self.typePrefix.count)))
    }

    private var title: String {
        switch self {
        case .newPalette: "New Palette"
        case .newColor: "New Color"
        case .scanColor: "Scan Color"
        case .generatePalette: "Generate Palette"
        }
    }

    private var symbol: String {
        switch self {
        case .newPalette: "swatchpalette"
        case .newColor: "plus.circle"
        case .scanColor: "eyedropper"
        case .generatePalette: "sparkles"
        }
    }

    var shortcutItem: UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: Self.typePrefix + rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: symbol)
        )
    }

    /// Generate only where Apple Intelligence can run it.
    static var available: [QuickAction] {
        allCases.filter { $0 != .generatePalette || AppleIntelligence.isDeviceSupported }
    }
}

/// The quick action waiting for a window to perform it.
@MainActor
final class QuickActionCenter: ObservableObject {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    static let shared = QuickActionCenter()

    @Published var pending: QuickAction?

    /// The pending action, cleared so only one window performs it.
    func take() -> QuickAction? {
        defer { pending = nil }
        return pending
    }
}

final class QuickActionAppDelegate: NSObject, UIApplicationDelegate {
    deinit {}

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.shortcutItems = QuickAction.available.map(\.shortcutItem)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = QuickActionSceneDelegate.self
        return configuration
    }
}

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    deinit {}

    /// Cold launch from a quick action.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem, let action = QuickAction(item) {
            QuickActionCenter.shared.pending = action
        }
    }

    /// A quick action while the app is already running.
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let action = QuickAction(shortcutItem) else { return completionHandler(false) }
        QuickActionCenter.shared.pending = action
        completionHandler(true)
    }
}

private struct ConsumeScanRequestKey: EnvironmentKey {
    static let defaultValue: () -> Bool = { false }
}

extension EnvironmentValues {
    /// True once, when Scan Color opened the sheet this editor is in:
    /// the editor then opens the camera by itself.
    var consumeScanRequest: () -> Bool {
        get { self[ConsumeScanRequestKey.self] }
        set { self[ConsumeScanRequestKey.self] = newValue }
    }
}
