//
//  WidgetLinkInbox.swift
//  Palettes (app + widgets)
//
//  The link OpenLinkIntent asked the app to open, waiting for a library
//  window (see PaletteTabView). Compiled into the extension too, where it
//  is never used.
//

import Combine
import Foundation

@MainActor
final class WidgetLinkInbox: ObservableObject {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    static let shared = WidgetLinkInbox()

    @Published var pending: WidgetLink?

    /// The pending link, cleared so only one window opens it.
    func take() -> WidgetLink? {
        defer { pending = nil }
        return pending
    }
}
