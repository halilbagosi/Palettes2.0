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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct EditTarget: Identifiable { let id: Int }
    @State private var editTarget: EditTarget?
    @State private var changeText = ""
    @FocusState private var changeFocused: Bool
    @FocusState private var nameFocused: Bool

    /// Base title size, scaled by Dynamic Type. The name field steps down from
    /// here as the name grows so long generated names stay on one line.
    @ScaledMetric(relativeTo: .title) private var baseNameSize: CGFloat = 28

    private static let nameCharacterLimit = 48

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
            // area stays clear of buttons and fields. It steps aside rather
            // than sliding off-screen — a full slide reads as "the bar left"
            // when it's really just yielding for a moment.
            if !nameFocused {
                VStack(spacing: 12) {
                    describeChangeField
                    // While typing, the field's send arrow takes over — hide the bar.
                    if !changeFocused {
                        actionBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.28), value: changeFocused)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .offset(y: 16))
                )
            }
        }
        .animation(.smooth(duration: 0.3), value: nameFocused)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onBack() } label: {
                    Image(systemName: "chevron.backward")
                        .fontWeight(.semibold)
                }
            }

            // Renaming hides the bottom bar, so the keyboard carries the only
            // commit affordance. Return works too; this is for thumbs.
            if nameFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done", action: commitName)
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $editTarget) { target in
            if target.id < colors.count, target.id < hexCodes.count, target.id < colorNames.count {
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
        // The generator can return mismatched array lengths; keep names and
        // hex codes in lockstep with the colors so index access is safe.
        .onAppear(perform: normalizeArrays)
        .onChange(of: colors.count) { _, _ in normalizeArrays() }
    }

    /// Pads or trims `hexCodes`/`colorNames` to match `colors` exactly.
    private func normalizeArrays() {
        while hexCodes.count < colors.count { hexCodes.append("") }
        while colorNames.count < colors.count { colorNames.append("Color \(colorNames.count + 1)") }
        if hexCodes.count > colors.count { hexCodes.removeLast(hexCodes.count - colors.count) }
        if colorNames.count > colors.count { colorNames.removeLast(colorNames.count - colors.count) }
    }

    // MARK: - Name

    /// Longer names get a smaller title so they stay on one line instead of
    /// truncating. Animating a point size (rather than swapping `Font` cases)
    /// is what lets the step-down interpolate instead of snapping.
    private var nameSize: CGFloat {
        switch name.count {
        case ..<18: baseNameSize
        case ..<30: baseNameSize * 0.85
        default:    baseNameSize * 0.72
        }
    }

    /// The chrome around the title animates; the `TextField` itself never
    /// changes identity, so focus and the caret survive the transition.
    private var nameField: some View {
        // Vertical axis so a name too long even at the smallest step wraps to a
        // second line rather than truncating mid-word.
        TextField("Name this palette", text: $name, axis: .vertical)
            .font(.system(size: nameSize, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(1...2)
            .textInputAutocapitalization(.words)
            .focused($nameFocused)
            .submitLabel(.done)
            .padding(.horizontal, 52)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background {
                // The field materializes under the finger rather than sitting
                // in a permanent box. Scales from 0.94, never from zero.
                if nameFocused {
                    Color.clear
                        .glassEffect(.regular, in: .capsule)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.94).combined(with: .opacity)
                        )
                }
            }
            // The visible title is the tap target; the side padding used to
            // swallow taps that landed just off the glyphs.
            .overlay {
                if !nameFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { nameFocused = true }
                }
            }
            .overlay(alignment: .trailing) { nameAccessory }
            .animation(.smooth(duration: 0.28), value: nameSize)
            .animation(.snappy(duration: 0.26), value: nameFocused)
            .animation(.snappy(duration: 0.2), value: name.isEmpty)
            .onChange(of: name) { _, newValue in
                // A vertical-axis field turns Return into a newline instead of
                // firing `onSubmit`, so treat any newline as "done".
                if newValue.contains(where: \.isNewline) {
                    name = newValue.filter { !$0.isNewline }
                    commitName()
                    return
                }
                guard newValue.count > Self.nameCharacterLimit else { return }
                name = String(newValue.prefix(Self.nameCharacterLimit))
            }
            .onChange(of: nameFocused) { _, focused in
                // Tapping away or dragging the keyboard down commits too, not
                // just the return key.
                if !focused { name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .sensoryFeedback(.selection, trigger: nameFocused)
    }

    /// Pencil while idle, clear button while editing — one slot, so the two
    /// swap in place instead of one appearing where the other was.
    @ViewBuilder
    private var nameAccessory: some View {
        Group {
            if nameFocused {
                if !name.isEmpty {
                    Button { name = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel("Clear palette name")
                    .transition(accessoryTransition)
                }
            } else {
                Button { nameFocused = true } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit palette name")
                .transition(accessoryTransition)
            }
        }
        .font(.title3)
        .foregroundStyle(.secondary)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .padding(.trailing, 6)
    }

    private var accessoryTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.7).combined(with: .opacity)
    }

    private func commitName() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        nameFocused = false
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
        .glassEffect(.regular.interactive(), in: .capsule)
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

#Preview("Long name") {
    @Previewable @State var name = "Warm Autumn Forest at Golden Hour"
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
