//
//  AppAppearance.swift
//  Palettes
//
//  The accent colors and app icon versions the user can choose between.
//

import SwiftUI
import UIKit

/// Accent colors, matching the three circles in the app icon.
enum AccentChoice: String, CaseIterable, Identifiable {
    case coral, amber, violet

    static let storageKey = "accentChoice"
    static let `default` = AccentChoice.coral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: "Coral"
        case .amber: "Amber"
        case .violet: "Violet"
        }
    }

    var color: Color {
        switch self {
        case .coral: Color(red: 1.0, green: 0.37, blue: 0.48)
        case .amber: Color(red: 1.0, green: 0.69, blue: 0.13)
        case .violet: Color(red: 0.48, green: 0.36, blue: 1.0)
        }
    }

    init(stored: String) {
        self = AccentChoice(rawValue: stored) ?? .default
    }

    /// Stored in place of a preset's raw value when the user picked their own color.
    static let customStored = "custom"
    static let customHexKey = "accentCustomHex"

    /// The tint for a stored choice; a custom choice reads its color from `customHex`.
    static func color(stored: String, customHex: String) -> Color {
        guard stored == customStored, let custom = Color(accentHex: customHex) else {
            return AccentChoice(stored: stored).color
        }
        return custom
    }
}

extension Color {
    /// `RRGGBB`, with or without a leading `#`.
    init?(accentHex hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `RRGGBB` in sRGB.
    var accentHex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

/// App icon versions. `auto` is the primary icon and follows the system's light
/// and dark mode; the others are alternates fixed to one look.
enum AppIconVersion: String, CaseIterable, Identifiable {
    case auto, light, dark

    /// Mirrors the chosen icon so views behind the Customize sheet update live;
    /// `UIApplication.alternateIconName` isn't observable.
    static let storageKey = "appIconChoice"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Name passed to `setAlternateIconName`; `nil` selects the primary icon.
    var alternateIconName: String? {
        switch self {
        case .auto: nil
        case .light: "AppIconLight"
        case .dark: "AppIconDark"
        }
    }

    /// Flat renderings of the icon for in-app display (`auto` combines both).
    var previewImageNames: (light: String, dark: String?) {
        switch self {
        case .auto: ("AppIconPreviewLight", "AppIconPreviewDark")
        case .light: ("AppIconPreviewLight", nil)
        case .dark: ("AppIconPreviewDark", nil)
        }
    }

    init(alternateIconName: String?) {
        self = AppIconVersion.allCases.first { $0.alternateIconName == alternateIconName } ?? .auto
    }

    @MainActor
    static var current: AppIconVersion {
        AppIconVersion(alternateIconName: UIApplication.shared.alternateIconName)
    }

    @MainActor
    func apply() async throws {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        try await UIApplication.shared.setAlternateIconName(alternateIconName)
    }
}

/// Whether the app follows the system's light or dark mode, or stays in one.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    private var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Overrides the look of every window, and so every sheet presented from them.
    @MainActor
    func applyToWindows() {
        for scene in UIApplication.shared.connectedScenes {
            for window in (scene as? UIWindowScene)?.windows ?? [] {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }

    /// The system's own light or dark mode, ignoring the app's override; it
    /// decides which look the Auto home screen icon has.
    @MainActor
    static var systemIsDark: Bool {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return scene?.screen.traitCollection.userInterfaceStyle == .dark
    }

    init(stored: String) {
        self = AppAppearance(rawValue: stored) ?? .system
    }
}
