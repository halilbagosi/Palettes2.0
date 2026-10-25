//
//  LargeTitleCompat.swift
//  Palettes
//
//  The library tabs' large title. iOS 26 and later: the plural ("Palettes")
//  with the count in a capsule beside it, through the `.largeTitle` toolbar
//  placement; scrolled up, the inline title is the plural alone. Earlier
//  systems keep the plain string title with the count in front ("12 Palettes").
//

import SwiftUI

extension View {
    /// The library title for `count` items of `noun` ("Palette"), or
    /// "N Selected" while selecting.
    /// The branch is on the OS only, so entering or leaving selection never
    /// swaps the view (and its scroll position) out.
    @ViewBuilder
    func libraryTitle(_ noun: String, count: Int, selectedCount: Int?) -> some View {
        let selecting = selectedCount.map { "\($0) Selected" }
        if #available(iOS 26.0, *) {
            navigationTitle(selecting ?? LibraryTitle.plural(noun))
                .toolbar {
                    if selecting == nil {
                        ToolbarItem(placement: .largeTitle) {
                            LibraryLargeTitle(noun: noun, count: count)
                        }
                    }
                }
        } else {
            navigationTitle(selecting ?? LibraryTitle.text(noun, count: count))
        }
    }
}

/// "Palettes (12)": the title with its count in a capsule. The number sits
/// on the title's baseline with digits a little shorter than its capitals;
/// the capsule grows around the number as far as it needs to.
private struct LibraryLargeTitle: View {
    let noun: String
    let count: Int

    /// Re-reads the font sizes when the text size changes.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

#if DEBUG
    // Triple-tap the title to tune these live (DEBUG builds only).
    @AppStorage(CountPillTuning.sizeKey) private var sizeRatio = CountPillTuning.defaultSize
    @AppStorage(CountPillTuning.insetKey) private var insetRatio = CountPillTuning.defaultInset
    @State private var showsTuning = false
#else
    private let sizeRatio = CountPillTuning.defaultSize
    private let insetRatio = CountPillTuning.defaultInset
#endif

    /// The count's font, as a fraction of the title's size. Digits are cap
    /// height, so 0.7 gives digits a little shorter than its capitals.
    private var countSize: CGFloat {
        (UIFont.preferredFont(forTextStyle: .largeTitle).pointSize * sizeRatio).rounded()
    }

    var body: some View {
        let font = UIFont.systemFont(ofSize: countSize, weight: .semibold)
        let inset = (font.capHeight * insetRatio).rounded()
        let pillHeight = font.capHeight + inset * 2
        // The text frame runs ascender to descender; move the capsule from
        // that frame's center to the digits' center.
        let shift = (font.ascender + font.descender - font.capHeight) / 2

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(LibraryTitle.plural(noun))
                .font(.largeTitle.bold())
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: countSize, weight: .semibold))
                    .monospacedDigit()
                    // Never truncate to "…" when the toolbar slot is short.
                    .fixedSize()
                    .contentTransition(.numericText(value: Double(count)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, inset * 1.2)
                    .frame(minWidth: pillHeight)
                    .background {
                        Capsule()
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: pillHeight)
                            .offset(y: shift)
                    }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LibraryTitle.text(noun, count: count))
        .accessibilityAddTraits(.isHeader)
#if DEBUG
        .onTapGesture(count: 3) { showsTuning = true }
        .sheet(isPresented: $showsTuning) {
            CountPillTuningPanel()
                .presentationDetents([.medium])
        }
#endif
    }
}

/// The count capsule's proportions. DEBUG builds can override them from a
/// panel (triple-tap a library title) to compare sizes on device.
private enum CountPillTuning {
    /// Count font size as a fraction of the title's.
    static let defaultSize = 0.7
    /// Capsule padding around the digits, as a fraction of their height.
    static let defaultInset = 0.3
    static let sizeKey = "debug.countPill.size"
    static let insetKey = "debug.countPill.inset"
}

#if DEBUG
private struct CountPillTuningPanel: View {
    @AppStorage(CountPillTuning.sizeKey) private var sizeRatio = CountPillTuning.defaultSize
    @AppStorage(CountPillTuning.insetKey) private var insetRatio = CountPillTuning.defaultInset

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    row("Number size", value: $sizeRatio, in: 0.4...1.1)
                    row("Pill padding", value: $insetRatio, in: 0.1...0.8)
                } footer: {
                    Text("Number size is a fraction of the title's font size; 0.7 makes the digits a little shorter than the capitals. Pill padding is a fraction of the digits' height.")
                }
                Section {
                    Button("Reset to defaults", role: .destructive) {
                        sizeRatio = CountPillTuning.defaultSize
                        insetRatio = CountPillTuning.defaultInset
                    }
                }
            }
            .navigationTitle("Count Pill Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ label: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.01)
        }
    }
}
#endif
