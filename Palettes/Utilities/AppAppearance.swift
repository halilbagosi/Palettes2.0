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
}

/// App icon versions. `dark` is the primary icon; the rest are alternates.
enum AppIconVersion: String, CaseIterable, Identifiable {
    case dark, light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// Name passed to `setAlternateIconName`; `nil` selects the primary icon.
    var alternateIconName: String? {
        switch self {
        case .dark: nil
        case .light: "AppIconLight"
        }
    }

    /// Flat rendering of the icon for in-app display.
    var previewImageName: String {
        switch self {
        case .dark: "AppIconPreviewDark"
        case .light: "AppIconPreviewLight"
        }
    }

    init(alternateIconName: String?) {
        self = AppIconVersion.allCases.first { $0.alternateIconName == alternateIconName } ?? .dark
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
