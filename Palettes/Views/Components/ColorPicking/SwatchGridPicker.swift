import SwiftUI

/// Apple-style swatch grid: "Your Colors" (most recent library colors) above
/// a 12 × 8 grid of hues by lightness. Tap or drag across cells to pick.
struct SwatchGridPicker: View {
    @Binding var color: Color
    var onPick: (Color) -> Void

    @EnvironmentObject private var appData: AppData

    /// Built once — `gridHexes()` makes 96 colors per call.
    private static let grid: [[(hex: String, color: Color)]] = ColorPickerModel.gridHexes().map { row in
        row.map { (hex: $0, color: Color(hex: $0) ?? .clear) }
    }
    private static let spacing: CGFloat = 2

    private var selectedHex: String { ColorComposer.hexKey(color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let recents = ColorPickerModel.recentColors(appData.colors)
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Colors")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recents) { item in
                                recentCircle(item)
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                }
            }
            swatchGrid
        }
        .sensoryFeedback(.selection, trigger: selectedHex)
    }

    private func recentCircle(_ item: ColorViewModel) -> some View {
        let isSelected = ColorComposer.hexKey(item.color) == selectedHex
        return Button {
            pick(item.color)
        } label: {
            Circle()
                .fill(item.color)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 1))
                .overlay {
                    if isSelected { Circle().strokeBorder(.white, lineWidth: 2).shadow(color: .black.opacity(0.3), radius: 2) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var swatchGrid: some View {
        let columns = ColorPickerModel.gridColumns
        let rows = ColorPickerModel.gridRows
        return GeometryReader { geo in
            let cell = (geo.size.width - Self.spacing * CGFloat(columns - 1)) / CGFloat(columns)
            Grid(horizontalSpacing: Self.spacing, verticalSpacing: Self.spacing) {
                ForEach(0..<rows, id: \.self) { r in
                    GridRow {
                        ForEach(0..<columns, id: \.self) { c in
                            let (hex, swatch) = Self.grid[r][c]
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(swatch)
                                .frame(width: cell, height: cell)
                                .overlay {
                                    if hex == selectedHex {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .strokeBorder(.white, lineWidth: 2)
                                            .shadow(color: .black.opacity(0.4), radius: 1.5)
                                    }
                                }
                                .accessibilityElement()
                                .accessibilityLabel(hex)
                                .accessibilityAddTraits(hex == selectedHex ? .isSelected : [])
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let col = min(max(Int(value.location.x / geo.size.width * CGFloat(columns)), 0), columns - 1)
                let row = min(max(Int(value.location.y / geo.size.height * CGFloat(rows)), 0), rows - 1)
                let cell = Self.grid[row][col]
                guard cell.hex != selectedHex else { return }
                pick(cell.color)
            })
        }
        .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
    }

    private func pick(_ new: Color) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { onPick(new) }
    }
}
