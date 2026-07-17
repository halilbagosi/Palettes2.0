//
//  ColorsCellBig.swift
//  Palettes
//

import SwiftUI

/// Full-bleed color card: the color fills the card edge to edge with the name
/// pill floating top-leading and the HEX + actions along the bottom as
/// same-sized liquid glass pills. Tapping the card opens the color's editor.
struct ColorCellBig: View {
    let colorName: String
    let hexCode: String
    let color: Color
    let isUsedInPalette: Bool
    /// Tapping the card body (opens the color detail view).
    var onCardTap: (() -> Void)? = nil
    /// Shown as a "View" pill; opens the color detail view.
    var onViewPalettes: (() -> Void)? = nil

    var body: some View {
        Rectangle()
            .fill(color.gradient)
            .frame(height: 180)
            .overlay(alignment: .topLeading) {
                namePill.padding(12)
            }
            .overlay(alignment: .bottom) {
                bottomBar.padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .compositingGroup()
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            // Only claim taps when a handler exists — an unconditional tap
            // gesture swallows taps meant for an enclosing NavigationLink.
            .modifier(OptionalTapModifier(action: onCardTap))
    }

    private var namePill: some View {
        Text(colorName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlass(.regular, in: .capsule)
    }

    private var bottomBar: some View {
        GlassContainer(spacing: 10) {
            HStack(spacing: 10) {
                hexPill

                Spacer(minLength: 0)

                if let onViewPalettes {
                    viewPalettesButton(onViewPalettes)
                }

                copyButton
            }
        }
    }

    private var hexPill: some View {
        Text(hexCode)
            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .liquidGlass(.regular, in: .capsule)
    }

    private func viewPalettesButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("View")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .capsule)
    }

    private var copyButton: some View {
        Button {
            copyToClipboard(hexCode, label: "Copied HEX")
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, height: 38)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .liquidGlass(.interactive, in: .circle)
        .accessibilityLabel("Copy HEX")
    }
}

/// Attaches a tap gesture only when an action is provided.
private struct OptionalTapModifier: ViewModifier {
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onTapGesture(perform: action)
        } else {
            content
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ColorCellBig(
                colorName: "Midnight Blue",
                hexCode: "#191970",
                color: Color(red: 0.1, green: 0.1, blue: 0.44),
                isUsedInPalette: true,
                onCardTap: {},
                onViewPalettes: {})

            ColorCellBig(
                colorName: "Neon Lime",
                hexCode: "#CCFF00",
                color: Color(red: 0.8, green: 1.0, blue: 0.0),
                isUsedInPalette: false,
                onCardTap: {})
        }
        .padding()
    }
}
