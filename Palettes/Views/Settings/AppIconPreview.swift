//
//  AppIconPreview.swift
//  Palettes
//
//  The app icon drawn as a squircle, for Settings and the customize sheet.
//

import SwiftUI

struct AppIconPreview: View {
    var version: AppIconVersion
    var size: CGFloat = 80

    var body: some View {
        Image(version.previewImageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(.rect(cornerRadius: size * 0.2237, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                    .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}
