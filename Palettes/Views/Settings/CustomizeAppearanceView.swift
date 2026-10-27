//
//  CustomizeAppearanceView.swift
//  Palettes
//
//  Pick the app's appearance, accent color and app icon version.
//

import SwiftUI

struct CustomizeAppearanceView: View {
    @AppStorage(AccentChoice.storageKey) private var accentStored = AccentChoice.default.rawValue
    @AppStorage(AccentChoice.customHexKey) private var customHex = ""
    @AppStorage(AppAppearance.storageKey) private var appearanceStored = AppAppearance.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppIconVersion.storageKey) private var iconStored = ""
    @State private var iconVersion = AppIconVersion.current
    @State private var showIconError = false
    @State private var colorPicker = SystemColorPicker()

    private var accent: AccentChoice { AccentChoice(stored: accentStored) }
    private var isCustom: Bool { accentStored == AccentChoice.customStored }

    /// Writing picks the custom accent, so dragging in the system picker applies live.
    private var customColor: Binding<Color> {
        Binding(
            get: { Color(accentHex: customHex) ?? accent.color },
            set: {
                customHex = $0.accentHex
                accentStored = AccentChoice.customStored
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    HStack(spacing: 0) {
                        ForEach(AppAppearance.allCases) { option in
                            let selected = AppAppearance(stored: appearanceStored) == option
                            Button {
                                appearanceStored = option.rawValue
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: option.systemImage)
                                        .font(.title2)
                                        .foregroundStyle(.primary)
                                        .frame(width: 72, height: 56)
                                        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14, style: .continuous))
                                        .overlay {
                                            if selected {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .strokeBorder(.tint, lineWidth: 3)
                                            }
                                        }
                                    Text(option.title)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(option.title) appearance")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Accent Color") {
                    HStack(spacing: 0) {
                        ForEach(AccentChoice.allCases) { choice in
                            Button {
                                accentStored = choice.rawValue
                            } label: {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(choice.color)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if !isCustom && choice == accent {
                                                Image(systemName: "checkmark")
                                                    .font(.headline.weight(.bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(choice.title)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(choice.title)
                            .accessibilityAddTraits(!isCustom && choice == accent ? .isSelected : [])
                        }

                        Button {
                            colorPicker.present(
                                selecting: customColor.wrappedValue,
                                onChange: { customColor.wrappedValue = $0 }
                            )
                        } label: {
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(isCustom
                                          ? AnyShapeStyle(customColor.wrappedValue)
                                          : AnyShapeStyle(AngularGradient(
                                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                                center: .center)))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if isCustom {
                                            Image(systemName: "checkmark")
                                                .font(.headline.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text("Custom")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Custom color")
                        .accessibilityAddTraits(isCustom ? .isSelected : [])
                    }
                    .padding(.vertical, 4)
                }

                Section("App Icon") {
                    HStack(spacing: 0) {
                        ForEach(AppIconVersion.allCases) { version in
                            Button {
                                select(version)
                            } label: {
                                VStack(spacing: 8) {
                                    AppIconPreview(version: version, size: 72)
                                        .overlay {
                                            if version == iconVersion {
                                                RoundedRectangle(cornerRadius: 72 * 0.2237, style: .continuous)
                                                    .strokeBorder(.tint, lineWidth: 3)
                                            }
                                        }
                                    Text(version.title)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(version.title) icon")
                            .accessibilityAddTraits(version == iconVersion ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .sensoryFeedback(.selection, trigger: accentStored)
            .sensoryFeedback(.selection, trigger: appearanceStored)
            .sensoryFeedback(.selection, trigger: iconVersion)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't change the app icon.", isPresented: $showIconError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func select(_ version: AppIconVersion) {
        guard version != iconVersion else { return }
        let previous = iconVersion
        iconVersion = version
        iconStored = version.rawValue
        Task {
            do {
                try await version.apply()
            } catch {
                iconVersion = previous
                iconStored = previous.rawValue
                showIconError = true
            }
        }
    }
}

/// Presents Apple's color picker from the topmost view controller. A button
/// opens it directly; SwiftUI's `ColorPicker` can't be opened from one.
@MainActor
final class SystemColorPicker: NSObject, UIColorPickerViewControllerDelegate {
    /// Not main-actor isolated: the synthesized isolated deinit crashes on
    /// iOS 17/18 (see CLAUDE.md).
    nonisolated deinit {}

    private var onChange: ((Color) -> Void)?

    func present(selecting color: Color, onChange: @escaping (Color) -> Void) {
        guard var top = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController }).first else { return }
        while let presented = top.presentedViewController { top = presented }

        self.onChange = onChange
        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(color)
        picker.supportsAlpha = false
        picker.delegate = self
        top.present(picker, animated: true)
    }

    func colorPickerViewController(_ viewController: UIColorPickerViewController,
                                   didSelect color: UIColor, continuously: Bool) {
        onChange?(Color(color))
    }
}
