//
//  GlassButtonCompat.swift
//  Palettes
//
//  Availability shim for the iOS 26 glass button styles. Any surrounding `.tint`
//  still applies in both paths.
//

import SwiftUI

extension View {
    /// `.glass` / `.glassProminent` button style on iOS 26+, `.bordered` /
    /// `.borderedProminent` on earlier systems.
    @ViewBuilder
    func glassButton(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
            } else {
                buttonStyle(.bordered)
            }
        }
    }
}
