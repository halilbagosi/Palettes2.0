import SwiftUI

// MARK: - Match Highlighting

/// Bolds and tints the first case-insensitive occurrence of `query` in `text`.
func highlightedText(_ text: String, matching query: String) -> AttributedString {
    var attributed = AttributedString(text)
    guard !query.isEmpty,
          let range = attributed.range(of: query, options: .caseInsensitive) else {
        return attributed
    }
    attributed[range].inlinePresentationIntent = .stronglyEmphasized
    attributed[range].foregroundColor = .accentColor
    return attributed
}

// MARK: - Section Header

struct SearchSectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.bold())

            Text("\(count)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Hue Filter Chip

struct HueChip: View {
    let title: String
    let tint: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                if isSelected, tint != nil {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .transition(.pop)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? selectedForeground : (tint ?? Color.primary))
            .background(
                Capsule()
                    .fill((tint ?? Color.accentColor).opacity(isSelected ? 1 : 0))
            )
            .liquidGlass(.interactive, in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var selectedForeground: Color {
        guard let tint else { return .white }

        let rgb = tint.rgbComponents
        let normalized = [rgb.r, rgb.g, rgb.b].map { $0 / 255.0 }
        let linear = normalized.map { component in
            component <= 0.03928
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]

        return luminance > 0.45 ? .black : .white
    }
}

// MARK: - Recent Searches Row

struct RecentSearchesRow: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(searches, id: \.self) { term in
                        Button {
                            onSelect(term)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(term)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .liquidGlass(.interactive, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Empty Library State

struct SearchEmptyLibraryView: View {
    let onCreate: () -> Void

    var body: some View {
        PaletteEmptyView(
            imageName: "magnifyingglass",
            title: "Nothing to search yet",
            message: "Your colors and palettes will gather here, ready to browse by hue, tag or name.",
            actionTitle: "Create a Palette",
            action: onCreate
        )
        .padding(.top, 48)
    }
}
