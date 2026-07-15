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
    let swatch: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let swatch {
                    Circle()
                        .fill(swatch.gradient)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                }
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                if isSelected, swatch != nil {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                if isSelected {
                    Capsule().fill(Color.accentColor)
                }
            }
            .liquidGlass(.interactive, in: .capsule)
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 16) {
            Image(systemName: "swatchpalette")
                .font(.system(size: 44))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)

            Text("Nothing to search yet")
                .font(.title3.bold())

            Text("Create colors and palettes and they'll show up here, ready to browse and search.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                onCreate()
            } label: {
                Label("Create a Palette", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .glassButton(prominent: true)
            .tint(.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
