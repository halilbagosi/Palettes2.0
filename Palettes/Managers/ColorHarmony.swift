//
//  ColorHarmony.swift
//  Palettes
//
//  The palette modes a user can pick. `PaletteBuilder` builds them.
//

import Foundation

/// A named color-harmony scheme, plus `.auto` (which `PaletteBuilder`
/// resolves to a concrete harmonic scheme) and the two interface modes.
enum HarmonyScheme: String, CaseIterable, Identifiable {
    case auto, complementary, splitComplementary, analogous, triadic, monochromatic, uiLight, uiDark

    var id: String { rawValue }

    var isUIMode: Bool {
        self == .uiLight || self == .uiDark
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .complementary: return "Complementary"
        case .splitComplementary: return "Split Complementary"
        case .analogous: return "Analogous"
        case .triadic: return "Triadic"
        case .monochromatic: return "Monochromatic"
        case .uiLight: return "UI Light"
        case .uiDark: return "UI Dark"
        }
    }
}
