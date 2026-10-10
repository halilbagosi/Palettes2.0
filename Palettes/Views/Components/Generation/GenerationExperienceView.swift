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

    @EnvironmentObject var appData: AppData

    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?
    @State private var changeText = ""
    @FocusState private var changeFocused: Bool
    @FocusState private var nameFocused: Bool
    /// Bands slide in one after another when the result appears.
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
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
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            // Hidden entirely while renaming the palette, so the keyboard
            // area stays clear of buttons and fields.
            if !nameFocused {
                VStack(spacing: 12) {
                    describeChangeField
                    // While typing, the field's send arrow takes over — hide the bar.
                    if !changeFocused {
                        actionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3), value: changeFocused)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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

    // MARK: - Name

    /// The generated name in the generated gradient; editing swaps in a field.
    private var nameField: some View {
        ZStack {
            if !nameFocused {
                OnboardingPaletteName(name: name.isEmpty ? "Untitled Palette" : name, usesGradient: true)
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture { nameFocused = true }
                    .accessibilityHidden(true)
            }
            nameTextField
                .opacity(nameFocused ? 1 : 0)
        }
    }

    private var nameTextField: some View {
        TextField("Palette Name", text: $name)
            .font(.system(.title, design: .rounded).weight(.bold))
            .multilineTextAlignment(.center)
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit {
                name = name.trimmingCharacters(in: .whitespaces)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 44)
            .overlay(alignment: .trailing) {
                if !nameFocused {
                    Button {
                        nameFocused = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Edit palette name")
                }
            }
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
    private static func ink(on color: Color) -> Color {
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
                .transition(.scale.combined(with: .opacity))
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

    // MARK: - Actions

    private var actionBar: some View {
        GlassContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .glassButton()

                Button {
                    onSave()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .glassButton(prominent: true)
            }
        }
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
