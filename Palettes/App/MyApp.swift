import SwiftUI

@main
struct MyApp: App {
    @AppStorage(OnboardingModel.completionKey) private var didCompleteOnboarding = false

    init() {
        // Exports are deleted after each share; this catches any left behind
        // by a crash or a kill mid-share.
        ExportFiles.removeAll()
    }

    var body: some Scene {
        WindowGroup {
           PaletteTabView()
                .toastOverlay()
                .fullScreenCover(isPresented: Binding(
                    get: { !didCompleteOnboarding },
                    set: { if !$0 { didCompleteOnboarding = true } }
                )) {
                    OnboardingView()
                }
        }
    }
}
