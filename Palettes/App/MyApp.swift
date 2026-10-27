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
        #if DEBUG
        ScreenshotSeed.applyIfRequested(to: .shared)
        #endif
    }

    var body: some Scene {
        WindowGroup(id: PalettesScene.libraryID) {
            #if DEBUG
            if MotionStage.isActive, #available(iOS 26.0, *) {
                MotionStageView()
            } else {
                AccentRoot {
                    PaletteTabView()
                        .toastOverlay()
                }
            }
            #else
            AccentRoot {
                PaletteTabView()
                    .toastOverlay()
            }
            #endif
        }
        .commands { PalettesCommands() }
    }
}

/// Applies the chosen accent color. The `@AppStorage` lives in a `View`, not the
/// `App`, because an `App`-level one stopped re-rendering after the first change.
private struct AccentRoot<Content: View>: View {
    @AppStorage(AccentChoice.storageKey) private var accentStored = AccentChoice.default.rawValue
    @AppStorage(AccentChoice.customHexKey) private var customHex = ""
    @AppStorage(AppAppearance.storageKey) private var appearanceStored = AppAppearance.system.rawValue
    @ViewBuilder let content: Content

    var body: some View {
        content
            .tint(AccentChoice.color(stored: accentStored, customHex: customHex))
            // On the windows, not `preferredColorScheme`: that left an already
            // presented sheet stuck on the look it opened with.
            .onChange(of: appearanceStored, initial: true) {
                AppAppearance(stored: appearanceStored).applyToWindows()
            }
    }
}
