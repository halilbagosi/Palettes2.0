//
//  AppLinks.swift
//  Palettes
//
//  Public contact details and web pages. `supportEmail` must match
//  PrivacyPolicy.md and the App Store Connect support/privacy contact; the
//  two pages are the App Store Connect Support and Privacy Policy URLs,
//  served by GitHub Pages from the halilbagosi/palettes-app repo.
//

import Foundation

enum AppLinks {
    static let supportEmail = "support@halilbagosi.com"

    static var supportEmailURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    static let feedbackEmail = "palettes.feedback@halilbagosi.com"

    /// A mailto link to `feedbackEmail`, its subject naming the app version
    /// and build.
    static var feedbackEmailURL: URL {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = feedbackEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Palettes Feedback (\(version) (\(build)))")]
        return components.url!
    }

    static let supportPage = URL(string: "https://palettes.halilbagosi.com/support/")!
    static let privacyPolicy = URL(string: "https://palettes.halilbagosi.com/privacy/")!

    /// Apple's standard EULA. Subscriptions (planned) must link Terms of Use
    /// in-app; swap for a custom EULA URL if one is published.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
