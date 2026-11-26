//
//  GenerationMode.swift
//  Palettes
//
//  What the Generate tab's Mode menu offers: Auto, which picks the color
//  style that best suits the chosen colors (never an interface mode); one
//  color style, pinned; or an interface mode, which steps through its own
//  styles on each generation.
//

import Foundation

enum GenerationMode: Hashable, Identifiable {
    case auto
    case style(PaletteStyle)
    case uiLight
    case uiDark

    /// The eight color styles, in menu order.
    static let colorStyles: [GenerationMode] = PaletteStyle.deck(for: .auto).map { .style($0) }
    static let interfaceModes: [GenerationMode] = [.uiLight, .uiDark]

    var id: String {
        switch self {
        case .auto: return "auto"
        case .style(let style): return "style.\(style.rawValue)"
        case .uiLight: return "uiLight"
        case .uiDark: return "uiDark"
        }
    }

    var displayName: String {
        switch self {
        case .auto: return HarmonyScheme.auto.displayName
        case .style(let style): return style.displayName
        case .uiLight: return HarmonyScheme.uiLight.displayName
        case .uiDark: return HarmonyScheme.uiDark.displayName
        }
    }

    /// The scheme the generator builds with. A pinned color style builds through Auto.
    var scheme: HarmonyScheme {
        switch self {
        case .auto, .style: return .auto
        case .uiLight: return .uiLight
        case .uiDark: return .uiDark
        }
    }

    /// The color style the user picked, if any.
    var pinnedStyle: PaletteStyle? {
        if case .style(let style) = self { return style }
        return nil
    }
}
