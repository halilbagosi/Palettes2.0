import SwiftUI

/// Coarse hue buckets used by the Search browse experience.
enum HueCategory: String, CaseIterable, Identifiable {
    case reds = "Reds"
    case oranges = "Oranges"
    case yellows = "Yellows"
    case greens = "Greens"
    case blues = "Blues"
    case purples = "Purples"
    case pinks = "Pinks"
    case neutrals = "Neutrals"

    var id: String { rawValue }

    /// Swatch shown in the filter chip.
    var representativeColor: Color {
        switch self {
        case .reds: return Color(hue: 0.0, saturation: 0.75, brightness: 0.85)
        case .oranges: return Color(hue: 0.08, saturation: 0.8, brightness: 0.9)
        case .yellows: return Color(hue: 0.15, saturation: 0.8, brightness: 0.95)
        case .greens: return Color(hue: 0.33, saturation: 0.65, brightness: 0.75)
        case .blues: return Color(hue: 0.6, saturation: 0.7, brightness: 0.85)
        case .purples: return Color(hue: 0.76, saturation: 0.6, brightness: 0.8)
        case .pinks: return Color(hue: 0.9, saturation: 0.55, brightness: 0.95)
        case .neutrals: return Color(hue: 0, saturation: 0, brightness: 0.6)
        }
    }
}

extension Color {
    /// Buckets the color by hue; low saturation or near-black goes to neutrals.
    var hueCategory: HueCategory {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        if s < 0.15 || b < 0.12 || (b > 0.95 && s < 0.08) {
            return .neutrals
        }

        let degrees = Double(h) * 360.0
        switch degrees {
        case ..<15, 345...: return .reds
        case ..<45: return .oranges
        case ..<70: return .yellows
        case ..<170: return .greens
        case ..<255: return .blues
        case ..<290: return .purples
        default: return .pinks
        }
    }

    /// Returns the RGB components formatted as "R: 255 G: 255 B: 255"
    var rgbString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rInt = Int(round(r * 255))
        let gInt = Int(round(g * 255))
        let bInt = Int(round(b * 255))
        
        return "R: \(rInt) G: \(gInt) B: \(bInt)"
    }
}
