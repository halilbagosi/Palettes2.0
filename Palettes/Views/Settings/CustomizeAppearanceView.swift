//
//  CustomizeAppearanceView.swift
//  Palettes
//
//  Pick the app's accent color and app icon version.
//

import SwiftUI

struct CustomizeAppearanceView: View {
    @AppStorage(AccentChoice.storageKey) private var accentStored = AccentChoice.default.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var iconVersion = AppIconVersion.current
    @State private var showIconError = false

    private var accent: AccentChoice { AccentChoice(stored: accentStored) }

    var body: some View {
        NavigationStack {
            Form {
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
                                            if choice == accent {
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
                            .accessibilityAddTraits(choice == accent ? .isSelected : [])
                        }
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
            .sensoryFeedback(.selection, trigger: accentStored)
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
        Task {
            do {
                try await version.apply()
            } catch {
                iconVersion = previous
                showIconError = true
            }
        }
    }
}
