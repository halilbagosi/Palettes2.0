//
//  PresentationCompat.swift
//  Palettes
//
//  `presentationSizing` is iOS 18+. This shim applies the `.form` sizing on 18+
//  and is a no-op on iOS 17.
//

import SwiftUI

extension View {
    @ViewBuilder
    func formPresentationSizing() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.form)
        } else {
            self
        }
    }
}
