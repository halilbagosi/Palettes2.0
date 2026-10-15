import AppIntents
import SwiftUI

@main
struct MyApp: App {
    @AppStorage(AccentChoice.storageKey) private var accentStored = AccentChoice.default.rawValue

    init() {
        // Exports are deleted after each share; this catches any left behind
        // by a crash or a kill mid-share.
        ExportFiles.removeAll()
        if #available(iOS 26.0, *) {
            PalettesShortcuts.updateAppShortcutParameters()
        }
    }

    var body: some Scene {
        WindowGroup(id: PalettesScene.libraryID) {
           PaletteTabView()
                .toastOverlay()
                .tint(AccentChoice(stored: accentStored).color)
        }
        .commands { PalettesCommands() }
    }
}
