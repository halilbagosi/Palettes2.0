//
//  GenerationExperienceView.swift
//  Palettes
//

import SwiftUI

/// Editable result stage shown inline after generation: the name in the
/// generated gradient over one tall swatch card, a band per color. Tap a band
/// to edit it, remove it from its trailing button, regenerate, or save.
struct GenerationResultView: View {
    @Binding var name: String
    @Binding var paletteColors: [PaletteColor]
    var onBack: () -> Void
    var onRegenerate: () -> Void
    var onDescribeChange: (String) -> Void
    var onSave: () -> Void
    /// Centre on the screen this far from both edges, ignoring the side safe
    /// area (landscape, where the bars sit on one side; see `centeredOnScreen`).
    var screenMargin: CGFloat?

    @EnvironmentObject var appData: AppData

    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?
    @State private var changeText = ""
    @FocusState private var changeFocused: Bool
    @FocusState private var nameFocused: Bool
    /// Bands slide in one after another when the result appears.
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// iPhone Duo half open (see `FoldCompat`): the palette takes the side
    /// before the crease and the change field the side after it.
    @State private var fold: Fold?
    /// Ties the palette across the folded and unfolded layouts.
    @Namespace private var foldNamespace

    var body: some View {
        ZStack {
            // Half open in portrait it keeps the portrait layout.
            if let fold, fold.isVertical {
                foldedBody(fold)
            } else {
                stackedBody
                    .centeredOnScreen(margin: screenMargin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onFoldChange { newFold in
            withAnimation(.smooth(duration: 0.35)) { fold = newFold }
        }
        .animation(.spring(response: 0.3), value: nameFocused)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.85)) {
                revealed = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.backward")
                        .fontWeight(.semibold)
                }
            }
            // Icons in the bar rather than buttons under the palette: on
            // iPhone Duo in landscape they join the vertical bar at the side.
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { onRegenerate() } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)

                Button { onSave() } label: {
                    Label("Save", systemImage: "checkmark")
                }
                .glassButton(prominent: true)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .sheet(item: $editTarget) { target in
            if target.id < paletteColors.count {
                ColorEditView(
                    colorName: $paletteColors[target.id].name,
                    hexCode: $paletteColors[target.id].hex,
                    colorValue: $paletteColors[target.id].color
                )
                .environmentObject(appData)
                .presentationDetents([.large])
                .formPresentationSizing()
            }
        }
    }

    // MARK: - Layout

    /// The palette in a scrolling column, the change field pinned
    /// under it.
    private var stackedBody: some View {
        ScrollView {
            paletteColumn
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            // Hidden entirely while renaming the palette, so the keyboard
            // area stays clear of the field.
            if !nameFocused {
                changeControls
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    /// Half open in landscape: the palette scrolls on the left side of the
    /// crease; the change field sits centred on the right.
    private func foldedBody(_ fold: Fold) -> some View {
        FoldSplit(fold: fold) {
            ScrollView {
                paletteColumn
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        } controls: {
            changeControls
                .opacity(nameFocused ? 0 : 1)
                .allowsHitTesting(!nameFocused)
                .frame(maxWidth: 480)
                .padding(.horizontal)
        }
    }

    private var paletteColumn: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                nameField
                Text("\(paletteColors.count) colors · Tap a color to edit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            swatchCard
        }
        .matchedGeometryEffect(id: "palette", in: foldNamespace)
    }

    /// Describe a change. Regenerate and Save are in the toolbar.
    private var changeControls: some View {
        describeChangeField
    }

    // MARK: - Name

    /// The generated name in the generated gradient. Editing swaps it for a field
    /// laid out identically, so nothing moves: the display text keeps its place
    /// (hidden) and the field sits exactly over it.
    private var nameField: some View {
        let shown = name.isEmpty ? "Untitled Palette" : name
        return OnboardingPaletteName(name: shown, usesGradient: true, trailingSymbol: "pencil")
            .lineLimit(3)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .opacity(nameFocused ? 0 : 1)
            .overlay {
                TextField("Palette Name", text: $name, axis: .vertical)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(1...3)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .onChange(of: name) { _, new in
                        // Return ends editing rather than adding a line.
                        if new.contains("\n") { name = new.replacingOccurrences(of: "\n", with: ""); nameFocused = false }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .opacity(nameFocused ? 1 : 0)
                    .allowsHitTesting(nameFocused)
                    .accessibilityHidden(!nameFocused)
            }
            .contentShape(Rectangle())
            .onTapGesture { nameFocused = true }
            .animation(.easeInOut(duration: 0.18), value: nameFocused)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Palette name, \(shown)")
            .accessibilityHint("Renames the palette")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { nameFocused = true }
    }

    // MARK: - Swatches

    /// One card, a full-width band per color with its name and hex in an ink
    /// that reads on it.
    private var swatchCard: some View {
        VStack(spacing: 0) {
            ForEach(paletteColors.indices, id: \.self) { i in
                band(at: i)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed || reduceMotion ? 0 : 18)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85).delay(Double(i) * 0.06), value: revealed)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 24, y: 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: paletteColors.count)
    }

    private func band(at index: Int) -> some View {
        let color = paletteColors[index]
        let ink = Self.ink(on: color.color)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(color.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(color.hex)
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .opacity(0.7)
            }
            Spacer(minLength: 8)
            if paletteColors.count > 2 {
                Button {
                    removeColor(at: index)
                } label: {
                    Image(systemName: "minus")
                        .font(.footnote.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(ink.opacity(0.14), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(color.name)")
            }
        }
        .foregroundStyle(ink)
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .frame(height: paletteColors.count <= 4 ? 88 : (paletteColors.count <= 6 ? 72 : 60))
        .frame(maxWidth: .infinity)
        .background(color.color)
        .contentShape(Rectangle())
        .onTapGesture { editTarget = EditTarget(id: index) }
        .contextMenu {
            Button("Edit Color", systemImage: "pencil") { editTarget = EditTarget(id: index) }
            if paletteColors.count > 2 {
                Button("Remove", systemImage: "minus.circle", role: .destructive) { removeColor(at: index) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Edits the color")
        .accessibilityAction { editTarget = EditTarget(id: index) }
    }

    /// Black or white, whichever contrasts more with `color`.
    /// Black or white, whichever reads on `color`.
    static func ink(on color: Color) -> Color {
        let rgb = color.rgbComponents
        let linear = [rgb.r, rgb.g, rgb.b].map { value -> Double in
            let c = value / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
        return luminance > 0.18 ? .black : .white
    }

    private func removeColor(at index: Int) {
        guard paletteColors.count > 2, index < paletteColors.count else { return }
        let removed = paletteColors[index]
        _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            paletteColors.remove(at: index)
        }
        ToastManager.shared.show("Color removed", icon: "trash.fill") {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                paletteColors.insert(removed, at: min(index, paletteColors.count))
            }
        }
    }

    // MARK: - Describe a Change

    private var describeChangeField: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.intelligence")
                .font(.title3)
                .foregroundStyle(.tint)

            TextField("Describe a change…", text: $changeText)
                .font(.body)
                .focused($changeFocused)
                .submitLabel(.go)
                .onSubmit(submitChange)

            if changeFocused || !changeText.trimmingCharacters(in: .whitespaces).isEmpty {
                let hasText = !changeText.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: submitChange) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(hasText ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                }
                .disabled(!hasText)
                .transition(.pop)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlass(.interactive, in: .capsule)
        .animation(.spring(response: 0.3), value: changeText.isEmpty)
        .animation(.spring(response: 0.3), value: changeFocused)
    }

    private func submitChange() {
        let text = changeText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        changeFocused = false
        onDescribeChange(text)
        changeText = ""
    }
}

#Preview {
    @Previewable @State var name = "Warm Autumn Forest"
    @Previewable @State var paletteColors: [PaletteColor] = [
        PaletteColor(color: Color(hex: "A95F4D")!, hex: "#A95F4D", name: "Amber"),
        PaletteColor(color: Color(hex: "D98A6C")!, hex: "#D98A6C", name: "Maple"),
        PaletteColor(color: Color(hex: "F5C79A")!, hex: "#F5C79A", name: "Goldenrod"),
        PaletteColor(color: Color(hex: "E29C88")!, hex: "#E29C88", name: "Moss"),
    ]

    NavigationStack {
        GenerationResultView(
            name: $name, paletteColors: $paletteColors,
            onBack: {}, onRegenerate: {}, onDescribeChange: { _ in }, onSave: {}
        )
    }
    .environmentObject(AppData())
}
