//
//  OpenLinkIntent.swift
//  Palettes (app + widgets)
//
//  Opens Palettes on a palettes:// link. Used where a URL can't be:
//  buttons in small widgets and Control Center / Lock Screen controls.
//  `openAppWhenRun` makes the system run perform() in the app.
//

import AppIntents
import Foundation

struct OpenLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Palettes"
    static let isDiscoverable = false
    /// Deprecated in the iOS 26 SDK in favor of `supportedModes`, which
    /// iOS 17 lacks. Keep it.
    static let openAppWhenRun = true

    @Parameter(title: "Link") var urlString: String

    init() {}

    init(_ link: WidgetLink) {
        urlString = link.url.absoluteString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: urlString), let link = WidgetLink(url: url) {
            WidgetLinkInbox.shared.pending = link
        }
        return .result()
    }
}
