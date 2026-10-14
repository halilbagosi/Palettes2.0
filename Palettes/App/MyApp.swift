import AppIntents
import SwiftUI

@main
struct MyApp: App {
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
        }
        .commands { PalettesCommands() }
    }
}
