//
//  PaletteStyle.swift
//  Palettes
//
//  The named design principles a generated palette follows. Each mode has a
//  deck of them, and generating again from the same colors steps through
//  the deck (see `StyleDeck`), so each result looks different. Interface
//  styles carry a role table; Auto styles carry a treatment on top of the
//  60/30/10 harmonic builder.
//
//  Pure — no UIKit — so it is fully unit-testable.
//

import Foundation

enum PaletteStyle: String, CaseIterable, Identifiable {
    // UI Light
    case tonal, cleanNeutral, warmEditorial, softPastel, highContrast, colorDrenched
    // UI Dark
    case tonalDark, oledBlack, midnight, dimGraphite, espresso, neon
    // Auto
    case analogous603010, complementaryPop, monochromePop, splitComplementary, triadicPlayful, pastel, jewelTones, earthy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tonal: return "Tonal"
        case .cleanNeutral: return "Clean Neutral"
        case .warmEditorial: return "Warm Editorial"
        case .softPastel: return "Soft Pastel"
        case .highContrast: return "High Contrast"
        case .colorDrenched: return "Color Drenched"
        case .tonalDark: return "Tonal Dark"
        case .oledBlack: return "OLED Black"
        case .midnight: return "Midnight"
        case .dimGraphite: return "Dim Graphite"
        case .espresso: return "Espresso"
        case .neon: return "Neon"
        case .analogous603010: return "Analogous 60-30-10"
        case .complementaryPop: return "Complementary Pop"
        case .monochromePop: return "Monochrome + Pop"
        case .splitComplementary: return "Split Complementary"
        case .triadicPlayful: return "Triadic Playful"
        case .pastel: return "Pastel"
        case .jewelTones: return "Jewel Tones"
        case .earthy: return "Earthy"
        }
    }

    /// The styles a mode steps through. Explicit harmonies have none.
    static func deck(for scheme: HarmonyScheme) -> [PaletteStyle] {
        switch scheme {
        case .uiLight: return [.tonal, .cleanNeutral, .warmEditorial, .softPastel, .highContrast, .colorDrenched]
        case .uiDark: return [.tonalDark, .oledBlack, .midnight, .dimGraphite, .espresso, .neon]
        case .auto: return [.analogous603010, .complementaryPop, .monochromePop, .splitComplementary, .triadicPlayful, .pastel, .jewelTones, .earthy]
        case .complementary, .splitComplementary, .analogous, .triadic, .monochromatic: return []
        }
    }
}

// MARK: - Interface styles

extension PaletteStyle {
    enum StyleHue: Equatable {
        /// Degrees from the primary's hue.
        case relative(Double)
        /// A hue of its own, whatever the primary: the style's character.
        case fixed(Double)
    }

    /// One role's OKLCH lightness and chroma, and where its hue comes from.
    struct RoleSpec: Equatable {
        let L: Double
        let C: Double
        let hue: StyleHue
    }

    /// The roles an interface style defines. Success, Warning and Error
    /// are shared by every style.
    static let interfaceRoleNames = ["Primary", "Background", "Surface", "Primary Container", "Text", "Muted Text", "Border", "Accent", "Secondary"]

    /// Role tables for UI Light and UI Dark styles; nil for Auto styles.
    var interfaceRoles: [String: RoleSpec]? {
        func table(_ specs: RoleSpec...) -> [String: RoleSpec] {
            Dictionary(uniqueKeysWithValues: zip(Self.interfaceRoleNames, specs))
        }
        func r(_ L: Double, _ C: Double, _ degrees: Double = 0) -> RoleSpec { RoleSpec(L: L, C: C, hue: .relative(degrees)) }
        func f(_ L: Double, _ C: Double, _ hue: Double) -> RoleSpec { RoleSpec(L: L, C: C, hue: .fixed(hue)) }

        // Order: Primary, Background, Surface, Primary Container, Text,
        // Muted Text, Border, Accent, Secondary.
        switch self {
        case .tonal:
            return table(r(0.55, 0.15), r(0.985, 0.008), r(0.95, 0.02), r(0.90, 0.06), r(0.24, 0.03), r(0.50, 0.03), r(0.88, 0.025), r(0.62, 0.14, 60), r(0.48, 0.08, 30))
        case .cleanNeutral:
            return table(r(0.50, 0.15), r(0.99, 0), r(0.96, 0), r(0.93, 0.03), r(0.20, 0), r(0.52, 0), r(0.89, 0), r(0.42, 0.14), r(0.72, 0.10))
        case .warmEditorial:
            return table(r(0.52, 0.13), f(0.965, 0.02, 85), f(0.93, 0.028, 80), r(0.90, 0.04), f(0.25, 0.03, 50), f(0.50, 0.03, 60), f(0.86, 0.035, 75), r(0.55, 0.11, 180), r(0.55, 0.07, -40))
        case .softPastel:
            return table(r(0.70, 0.11), r(0.975, 0.018), r(0.935, 0.045, 40), r(0.92, 0.06), r(0.33, 0.05), r(0.55, 0.04), r(0.88, 0.04), r(0.80, 0.10, 40), r(0.82, 0.08, -50))
        case .highContrast:
            return table(r(0.55, 0.20), r(1.0, 0), r(0.965, 0), r(0.86, 0.13), r(0.14, 0), r(0.38, 0), r(0.18, 0), r(0.66, 0.22, 180), f(0.88, 0.17, 100))
        case .colorDrenched:
            return table(r(0.50, 0.16), r(0.94, 0.045), r(0.90, 0.06), r(0.85, 0.08), r(0.22, 0.07), r(0.42, 0.06), r(0.82, 0.07), r(0.60, 0.17, 180), r(0.35, 0.10))
        case .tonalDark:
            return table(r(0.72, 0.14), r(0.18, 0.012), r(0.25, 0.02), r(0.32, 0.06), r(0.95, 0.01), r(0.72, 0.02), r(0.35, 0.025), r(0.76, 0.13, 60), r(0.68, 0.08, 30))
        case .oledBlack:
            return table(r(0.74, 0.16), r(0, 0), r(0.17, 0), r(0.26, 0.05), r(0.93, 0), r(0.66, 0), r(0.27, 0), r(0.78, 0.17, 180), r(0.70, 0.10))
        case .midnight:
            return table(r(0.72, 0.14), f(0.19, 0.045, 265), f(0.25, 0.05, 265), r(0.33, 0.07), f(0.94, 0.02, 250), f(0.72, 0.04, 255), f(0.36, 0.06, 265), r(0.80, 0.12, 150), f(0.70, 0.10, 220))
        case .dimGraphite:
            return table(r(0.70, 0.12), r(0.27, 0.006), r(0.32, 0.008), r(0.38, 0.04), r(0.90, 0.006), r(0.68, 0.008), r(0.40, 0.01), r(0.74, 0.10, 120), r(0.65, 0.06, 30))
        case .espresso:
            return table(r(0.72, 0.13), f(0.20, 0.022, 55), f(0.26, 0.028, 55), r(0.34, 0.05), f(0.93, 0.025, 85), f(0.72, 0.03, 75), f(0.36, 0.035, 60), f(0.78, 0.13, 75), r(0.66, 0.08, -30))
        case .neon:
            return table(r(0.78, 0.19), r(0.15, 0.035), r(0.21, 0.05), r(0.30, 0.10), r(0.96, 0.02), r(0.70, 0.05), r(0.40, 0.12), r(0.84, 0.19, 180), r(0.80, 0.17, -90))
        default:
            return nil
        }
    }
}

// MARK: - Auto treatments

extension PaletteStyle {
    /// How an Auto style bends the 60/30/10 harmonic builder.
    struct Treatment: Equatable {
        /// The harmonies it can build; the seed picks when there are several.
        var harmonies: [HarmonyScheme]
        /// Replaces the scheme's accent offset (degrees from the main hue).
        var accentOffset: Double? = nil
        /// The secondary share goes to tones of the main color instead.
        var dropsSecondary = false
        /// Gives a monochromatic palette one accent (plain monochromatic has none).
        var addsAccent = false
        /// The accent takes vivid chroma whatever the tone.
        var vividAccent = false
        /// Multiplies the chroma of generated tones.
        var chromaScale = 1.0
        /// A tone it brings. A vibe's own tone wins channel by channel.
        var tone: PaletteTone? = nil
        /// Fraction of the shorter way each generated family's hue moves toward 60° (earth).
        var earthPull = 0.0
    }

    var treatment: Treatment? {
        switch self {
        case .analogous603010:
            return Treatment(harmonies: [.analogous], accentOffset: 60)
        case .complementaryPop:
            return Treatment(harmonies: [.complementary], accentOffset: 180, dropsSecondary: true, vividAccent: true)
        case .monochromePop:
            return Treatment(harmonies: [.monochromatic], accentOffset: 150, addsAccent: true, vividAccent: true)
        case .splitComplementary:
            return Treatment(harmonies: [.splitComplementary])
        case .triadicPlayful:
            return Treatment(harmonies: [.triadic], chromaScale: 1.2)
        case .pastel:
            return Treatment(harmonies: [.analogous, .complementary], tone: PaletteTone(lightness: .light, chroma: .muted))
        case .jewelTones:
            return Treatment(harmonies: [.triadic, .splitComplementary], tone: PaletteTone(lightness: .dark, chroma: .vivid))
        case .earthy:
            return Treatment(harmonies: [.analogous, .complementary], chromaScale: 0.6, earthPull: 0.25)
        default:
            return nil
        }
    }

    /// The Auto style that stands for a harmony: the one the deck keeps when
    /// the user's colors imply that harmony, or leads with when a vibe asks for it.
    static func treatment(for harmony: HarmonyScheme) -> PaletteStyle? {
        switch harmony {
        case .analogous: return .analogous603010
        case .complementary: return .complementaryPop
        case .monochromatic: return .monochromePop
        case .splitComplementary: return .splitComplementary
        case .triadic: return .triadicPlayful
        case .auto, .uiLight, .uiDark: return nil
        }
    }
}
