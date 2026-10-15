import SwiftUI

/// The gear that opens Settings. Used as the leading toolbar item on each tab's
/// root screen; the sheet itself is presented by `PaletteTabView`.
struct SettingsToolbarButton: View {
    @EnvironmentObject private var router: SceneRouter

    var body: some View {
        Button {
            router.isShowingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}
