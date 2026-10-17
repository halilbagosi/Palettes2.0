//
//  AppLinks.swift
//  Palettes
//
//  Public contact details and web pages. `supportEmail` must match
//  PrivacyPolicy.md and the App Store Connect support/privacy contact; the
//  two pages are the App Store Connect Support and Privacy Policy URLs,
//  served from the halilbagosi/palettes-app repo.
//

import Foundation

enum AppLinks {
    static let supportEmail = "support@halilbagosi.com"

    static var supportEmailURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    static let supportPage = URL(string: "https://halilbagosi.github.io/palettes-app/support/")!
    static let privacyPolicy = URL(string: "https://halilbagosi.github.io/palettes-app/privacy/")!

    /// Apple's standard EULA. Subscriptions (planned) must link Terms of Use
    /// in-app; swap for a custom EULA URL if one is published.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
