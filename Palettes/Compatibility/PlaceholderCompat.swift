//
//  PlaceholderCompat.swift
//  Palettes
//
//  The system placeholder (about 30% label) is too faint on the tinted surfaces
//  the pre-iOS 26 glass fallback produces, and `prompt:` styling is ignored
//  there. This draws the placeholder in `.secondary` instead.
//

import SwiftUI

extension View {
    /// Overlays `text` in `.secondary` while `isEmpty`. Pair with a field whose
    /// own prompt is empty.
    func legiblePlaceholder(_ text: String, isEmpty: Bool, alignment: Alignment = .leading) -> some View {
        overlay(alignment: alignment) {
            if isEmpty {
                Text(text)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}
