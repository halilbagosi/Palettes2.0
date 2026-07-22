//
//  GenerationExperienceView.swift
//  Palettes
//

import SwiftUI

/// Editable result stage shown inline after generation: rename the palette,
/// edit or remove individual colors, regenerate, or save.
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                nameField
                    .padding(.top, 8)

                swatchStrip
                colorList
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

    private var nameField: some View {
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

    private var swatchStrip: some View {
        HStack(spacing: 0) {
            ForEach(paletteColors.indices, id: \.self) { i in
                Rectangle().fill(paletteColors[i].color)
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: paletteColors.count)
    }

    // MARK: - Color Rows

    private var colorList: some View {
        VStack(spacing: 10) {
            ForEach(paletteColors.indices, id: \.self) { i in
                colorRow(at: i)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: paletteColors.count)
    }

    private func colorRow(at index: Int) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(paletteColors[index].color.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(paletteColors[index].name)
                    .font(.system(size: 15, weight: .semibold))
                Text(paletteColors[index].hex)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                editTarget = EditTarget(id: index)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Edit color")

            Button {
                removeColor(at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(paletteColors.count > 2 ? Color.red.opacity(0.8) : Color.secondary.opacity(0.4))
            }
            .disabled(paletteColors.count <= 2)
            .accessibilityLabel("Remove color")
        }
        .padding(10)
        .liquidGlass(.regular, in: .rect(cornerRadius: 16))
    }

    private func removeColor(at index: Int) {
        guard paletteColors.count > 2, index < paletteColors.count else { return }
        let removed = paletteColors[index]
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
