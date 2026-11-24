import SwiftUI

/// Renders a palette, or a single color, as a shareable PNG image.
struct PaletteImageRenderer {

    @MainActor
    static func renderImage(for palette: PaletteViewModel, colors: [ColorViewModel]) -> UIImage? {
        let content = PaletteExportView(palette: palette, colorVMs: colors)
        let renderer = ImageRenderer(content: content.frame(width: 800))
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// The palette with its own color names (no library lookup).
    @MainActor
    static func renderImage(for palette: PaletteViewModel) -> UIImage? {
        let colorVMs = palette.paletteColors.map {
            ColorViewModel(name: $0.name, color: $0.color, HEX: $0.hex, usedInPalette: true)
        }
        return renderImage(for: palette, colors: colorVMs)
    }

    @MainActor
    static func renderImage(for color: ColorViewModel) -> UIImage? {
        let renderer = ImageRenderer(content: ColorExportView(color: color).frame(width: 600))
        renderer.scale = 3.0
        return renderer.uiImage
    }

    /// Opens the share sheet with the color as a PNG (it offers Save Image),
    /// or shows a toast when rendering fails.
    @MainActor
    static func shareImage(for color: ColorViewModel) {
        if let image = renderImage(for: color) {
            ShareSheetPresenter.present(items: [image])
        } else {
            ToastManager.shared.show("Unable to create PNG", icon: "exclamationmark.triangle")
        }
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

/// One color as a card: the swatch, then its name, HEX and RGB.
private struct ColorExportView: View {
    let color: ColorViewModel

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color.color)
                .frame(height: 420)

            VStack(spacing: 6) {
                Text(color.name)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                Text(color.HEX.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                Text(color.color.rgbString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
        }
    }
}
