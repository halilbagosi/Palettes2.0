//
//  AppLinks.swift
//  Palettes
//
//  Public contact details. `supportEmail` must match PrivacyPolicy.md and the
//  App Store Connect support/privacy contact.
//

import Foundation

enum AppLinks {
    // TODO(owner): replace with the dedicated support address before submission
    // (also in Palettes/Resources/PrivacyPolicy.md).
    static let supportEmail = "support@example.com"

    static var supportEmailURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Apple's standard EULA. Subscriptions (planned) must link Terms of Use
    /// in-app; swap for a custom EULA URL if one is published.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
