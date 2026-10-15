//
//  AnyTransition+Pop.swift
//  Palettes
//
//  The entrance for small controls and badges that appear in place (a send
//  button, a selection checkmark). `.scale` alone grows from nothing, which
//  reads as appearing out of thin air; starting most of the way there and
//  fading in keeps the shape present throughout.
//

import SwiftUI

extension AnyTransition {
    static var pop: AnyTransition {
        .scale(scale: 0.85).combined(with: .opacity)
    }
}
