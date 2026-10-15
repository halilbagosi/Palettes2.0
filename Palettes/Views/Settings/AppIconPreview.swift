//
//  AppIconPreview.swift
//  Palettes
//
//  The app icon as rendered by Icon Composer (already masked to a squircle),
//  for Settings and the customize sheet. `auto` splits light and dark.
//

import SwiftUI

struct AppIconPreview: View {
    var version: AppIconVersion
    var size: CGFloat = 80
    /// Show `auto` as the one look the system is using now, not split in two.
    var resolvesAuto = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let names = version.previewImageNames
        ZStack {
            if resolvesAuto && version == .auto {
                // The home screen follows the system, not the app's own override.
                // Reading the environment re-runs this when the look changes.
                let _ = colorScheme
                icon(AppAppearance.systemIsDark ? "AppIconPreviewDark" : "AppIconPreviewLight")
            } else {
                icon(names.light)
                if let dark = names.dark {
                    icon(dark)
                        .mask(alignment: .trailing) {
                            Rectangle().frame(width: size / 2)
                        }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func icon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
