import SwiftUI
import Combine

@MainActor
class AppData: ObservableObject {
    @Published var activeTab: TabValue = .palettes

    @Published var colors: [ColorViewModel] = [
        ColorViewModel(name: "Maroon", color: Color(hex: "800000")!, HEX: "#800000", usedInPalette: true),
        ColorViewModel(name: "Electric Blue", color: Color(hex: "007AFF")!, HEX: "#007AFF", usedInPalette: false),
        ColorViewModel(name: "Sunset Orange", color: Color(hex: "FF5D00")!, HEX: "#FF5D00", usedInPalette: true),
        ColorViewModel(name: "Neon Lime", color: Color(hex: "CCFF00")!, HEX: "#CCFF00", usedInPalette: true),
        ColorViewModel(name: "Hot Pink", color: Color(hex: "FF0080")!, HEX: "#FF0080", usedInPalette: true),
        ColorViewModel(name: "Pastel Mint", color: Color(hex: "99FA99")!, HEX: "#99FA99", usedInPalette: true),
        ColorViewModel(name: "Soft Lavender", color: Color(hex: "E6E6FA")!, HEX: "#E6E6FA", usedInPalette: true),
        ColorViewModel(name: "Peach", color: Color(hex: "FFCC99")!, HEX: "#FFCC99", usedInPalette: false),
        ColorViewModel(name: "Midnight", color: Color(hex: "1A1A70")!, HEX: "#1A1A70", usedInPalette: true),
        ColorViewModel(name: "Charcoal", color: Color(hex: "333333")!, HEX: "#333333", usedInPalette: true),
        ColorViewModel(name: "Forest Green", color: Color(hex: "1B4D1B")!, HEX: "#1B4D1B", usedInPalette: true),
    ]
    
    @Published var palettes: [PaletteViewModel] = [
        PaletteViewModel(
            name: "Midnight Ocean",
            colors: [
                Color(hex: "1A1A70")!,
                Color(hex: "007AFF")!,
                Color(hex: "99FA99")!,
                Color(hex: "E6E6FA")!
            ],
            hexCodes: ["#1A1A70", "#007AFF", "#99FA99", "#E6E6FA"],
            colorNames: ["Midnight", "Electric Blue", "Pastel Mint", "Soft Lavender"]
        ),
        PaletteViewModel(
            name: "Sunset Glow",
            colors: [
                Color(hex: "FF5D00")!,
                Color(hex: "FF0080")!,
                Color(hex: "CCFF00")!,
                Color(hex: "FFCC99")!
            ],
            hexCodes: ["#FF5D00", "#FF0080", "#CCFF00", "#FFCC99"],
            colorNames: ["Sunset Orange", "Hot Pink", "Neon Lime", "Peach"]
        ),
        PaletteViewModel(
            name: "Forest Floor",
            colors: [
                Color(hex: "1B4D1B")!,
                Color(hex: "99FA99")!,
                Color(hex: "333333")!
            ],
            hexCodes: ["#1B4D1B", "#99FA99", "#333333"],
            colorNames: ["Forest Green", "Pastel Mint", "Charcoal"]
        ),
        PaletteViewModel(
            name: "Warm Dusk",
            colors: [
                Color(hex: "D4456A")!,
                Color(hex: "FF8C42")!,
                Color(hex: "FBD87F")!,
                Color(hex: "2E1A47")!
            ],
            hexCodes: ["#D4456A", "#FF8C42", "#FBD87F", "#2E1A47"],
            colorNames: ["Crimson", "Dark Orange", "Khaki", "Indigo"]
        ),
        PaletteViewModel(
            name: "Bold Contrast",
            colors: [
                Color(hex: "800000")!,
                Color(hex: "333333")!,
                Color(hex: "E6E6FA")!,
                Color(hex: "CCFF00")!
            ],
            hexCodes: ["#800000", "#333333", "#E6E6FA", "#CCFF00"],
            colorNames: ["Maroon", "Charcoal", "Soft Lavender", "Neon Lime"]
        ),
    ]
}
