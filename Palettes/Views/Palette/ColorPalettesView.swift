import SwiftUI

struct ColorPalettesView: View {
    let colorItem: ColorViewModel
    let palettes: [PaletteViewModel]

    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) private var colorScheme

    private var gradientEnd: Color {
        let uiColor = UIColor(colorItem.color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if colorScheme == .dark {
            return Color(hue: Double(h), saturation: Double(s), brightness: 0.08)
        } else {
            return Color(hue: Double(h), saturation: Double(s * 0.08), brightness: 0.97)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // HEX & RGB Info Header
                HStack(spacing: 12) {
                    Text(colorItem.HEX)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    
                    Text(colorItem.color.rgbString)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }
                .foregroundColor(colorItem.color.isLight ? .black : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 8)
                .padding(.bottom, 12)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 560), spacing: 14)], spacing: 14) {
                    ForEach(palettes) { palette in
                        NavigationLink(value: palette) {
                            PaletteCellSearch(paletteName: palette.name, colors: palette.colors)
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.lift)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(
            LinearGradient(
                colors: [colorItem.color, gradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("\(colorItem.name) Palettes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(colorItem.color.isLight ? .light : .dark, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        ColorPalettesView(
            colorItem: ColorViewModel(
                name: "Maroon",
                color: Color(red: 128/255, green: 0, blue: 0),
                HEX: "#800000",
                usedInPalette: true
            ),
            palettes: [
                PaletteViewModel(
                    name: "Bold Contrast",
                    colors: [.red, .gray, .purple, .green],
                    hexCodes: ["#800000", "#333333", "#E6E6FA", "#CCFF00"],
                    colorNames: ["Maroon", "Charcoal", "Soft Lavender", "Neon Lime"]
                ),
                PaletteViewModel(
                    name: "Warm Dusk",
                    colors: [.red, .orange, .yellow, .indigo],
                    hexCodes: ["#D4456A", "#FF8C42", "#FBD87F", "#2E1A47"],
                    colorNames: ["Crimson", "Dark Orange", "Khaki", "Indigo"]
                )
            ]
        )
    }
}
