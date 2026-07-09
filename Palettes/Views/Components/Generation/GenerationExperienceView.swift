//
//  GenerationExperienceView.swift
//  Palettes
//

import SwiftUI

/// Editable result stage shown inline after generation: rename the palette,
/// edit or remove individual colors, regenerate, or save.
struct GenerationResultView: View {
    @Binding var name: String
    @Binding var colors: [Color]
    @Binding var hexCodes: [String]
    @Binding var colorNames: [String]
    var onBack: () -> Void
    var onRegenerate: () -> Void
    var onDescribeChange: (String) -> Void
    var onSave: () -> Void

    @EnvironmentObject var appData: AppData

    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?
    @State private var changeText = ""
    @FocusState private var changeFocused: Bool

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
            VStack(spacing: 12) {
                describeChangeField
                actionBar
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom, 8)
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
            if target.id < colors.count {
                ColorEditView(
                    colorName: $colorNames[target.id],
                    hexCode: $hexCodes[target.id],
                    colorValue: $colors[target.id]
                )
                .environmentObject(appData)
                .presentationDetents([.large])
                .presentationSizing(.form)
            }
        }
    }

    // MARK: - Name

    private var nameField: some View {
        HStack(spacing: 8) {
            TextField("Palette Name", text: $name)
                .font(.system(.title, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "pencil")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Swatches

    private var swatchStrip: some View {
        HStack(spacing: 0) {
            ForEach(colors.indices, id: \.self) { i in
                Rectangle().fill(colors[i])
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: colors.count)
    }

    // MARK: - Color Rows

    private var colorList: some View {
        VStack(spacing: 10) {
            ForEach(colors.indices, id: \.self) { i in
                colorRow(at: i)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: colors.count)
    }

    private func colorRow(at index: Int) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colors[index].gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(index < colorNames.count ? colorNames[index] : "Color \(index + 1)")
                    .font(.system(size: 15, weight: .semibold))
                Text(index < hexCodes.count ? hexCodes[index] : "")
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
                    .foregroundStyle(colors.count > 2 ? Color.red.opacity(0.8) : Color.secondary.opacity(0.4))
            }
            .disabled(colors.count <= 2)
            .accessibilityLabel("Remove color")
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }

    private func removeColor(at index: Int) {
        guard colors.count > 2, index < colors.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            colors.remove(at: index)
            if index < hexCodes.count { hexCodes.remove(at: index) }
            if index < colorNames.count { colorNames.remove(at: index) }
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

            if !changeText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: submitChange) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.spring(response: 0.3), value: changeText.isEmpty)
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
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 16) {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)

                Button {
                    onSave()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }
}

#Preview {
    @Previewable @State var name = "Warm Autumn Forest"
    @Previewable @State var colors: [Color] = [Color(hex: "A95F4D")!, Color(hex: "D98A6C")!, Color(hex: "F5C79A")!, Color(hex: "E29C88")!]
    @Previewable @State var hexes = ["#A95F4D", "#D98A6C", "#F5C79A", "#E29C88"]
    @Previewable @State var names = ["Amber", "Maple", "Goldenrod", "Moss"]

    NavigationStack {
        GenerationResultView(
            name: $name, colors: $colors, hexCodes: $hexes, colorNames: $names,
            onBack: {}, onRegenerate: {}, onDescribeChange: { _ in }, onSave: {}
        )
    }
    .environmentObject(AppData())
}
