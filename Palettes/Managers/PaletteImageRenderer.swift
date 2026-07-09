import SwiftUI

/// Renders a palette as a shareable PNG image.
struct PaletteImageRenderer {
    
    @MainActor
    static func renderImage(for palette: PaletteViewModel, colors: [ColorViewModel]) -> UIImage? {
        let content = PaletteExportView(palette: palette, colorVMs: colors)
        let renderer = ImageRenderer(content: content.frame(width: 800))
        renderer.scale = 3.0
        return renderer.uiImage
    }
}

private struct PaletteExportView: View {
    let palette: PaletteViewModel
    let colorVMs: [ColorViewModel]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, color in
                    Rectangle().fill(color)
                }
            }
            .frame(height: 300)
            
            HStack(spacing: 0) {
                ForEach(Array(colorVMs.enumerated()), id: \.offset) { _, colorVM in
                    VStack(spacing: 4) {
                        Text(colorVM.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(colorVM.HEX)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .background(Color(.systemBackground))
            
            Text(palette.name)
                .font(.system(size: 18, weight: .bold))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
        }
    }
}
