//
//  OnboardingLibraryTour.swift
//  Palettes
//
//  The last onboarding moment: after "Start creating" on the extras sheet the
//  Palettes tab returns to its library and this card drops in under the view-options
//  button, showing the display and filter options it holds as live controls.
//  Changing one here changes the library behind it, exactly like the menu.
//

import SwiftUI

struct LibraryOptionsTourCard: View {
    @Binding var layout: ListLayout
    @Binding var sort: LibrarySort
    @Binding var favoritesOnly: Bool
    @Binding var originFilter: LibraryOriginFilter
    var onDone: () -> Void

    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            VStack(spacing: 0) {
                toggleRow("Compact View", systemImage: "rectangle.compress.vertical", isOn: compactBinding)
                Divider().padding(.leading, 36)
                toggleRow("Favorites Only", systemImage: "star", isOn: $favoritesOnly)
            }
            segmentRow("Show") {
                Picker("Show", selection: $originFilter) {
                    ForEach(LibraryOriginFilter.allCases) { Text($0.label).tag($0) }
                }
            }
            segmentRow("Sort By") {
                Picker("Sort By", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                }
            }
            Button(action: onDone) {
                Text("Got it")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .glassCapsuleButton()
        }
        .padding(18)
        .frame(maxWidth: 380)
        .liquidGlass(.regular, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 10)
        // A banner over the library, not content: cap it before it outgrows the screen.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .onAppear { titleFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("Make your library yours")
                    .font(.system(.headline, design: .rounded))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                Text("Choose how palettes look and which ones show. They\u{2019}re always in the \(Image(systemName: LibraryOptionsLabel.systemImage)) menu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggleRow(_ title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .font(.body)
        }
        .padding(.vertical, 8)
    }

    private func segmentRow<P: View>(_ title: String, @ViewBuilder picker: () -> P) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            picker()
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }

    private var compactBinding: Binding<Bool> {
        Binding(get: { layout == .compact }, set: { layout = $0 ? .compact : .normal })
    }
}
