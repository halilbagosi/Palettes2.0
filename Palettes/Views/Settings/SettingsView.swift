//
//  SettingsView.swift
//  Palettes
//
//  A header with the user's library, then iCloud status, library export,
//  help, legal, and — on its own at the bottom — deleting all data.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appData: AppData
    @EnvironmentObject private var replay: OnboardingReplayCoordinator
    #if DEBUG
    @State private var debugStart = "pull"
    @AppStorage(OnboardingDebug.slowMoToggleKey) private var debugSlowMo = false
    @AppStorage(OnboardingDebug.aiOverrideKey) private var debugAI = OnboardingDebug.AIOverride.automatic.rawValue
    #endif
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false
    @State private var showExportError = false

    private var isSignedInToICloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    private var librarySummary: String {
        "\(plural(appData.palettes.count, "palette")) · \(plural(appData.colors.count, "color"))"
    }

    /// What "Delete All Data" removes, counted when there's anything to count.
    private var deleteScope: String {
        guard !libraryIsEmpty else { return "every color, palette, and tag" }
        let palettes = plural(appData.palettes.count, "palette")
        let colors = plural(appData.colors.count, "color")
        return "\(palettes), \(colors), and every tag"
    }

    private var libraryIsEmpty: Bool {
        appData.palettes.isEmpty && appData.colors.isEmpty
    }

    /// The most recent palette's colors stand in for an app icon in the
    /// header, so Settings wears the user's own work; a spectrum until then.
    private var headerColors: [Color] {
        if let palette = appData.palettes.last, palette.colors.count >= 2 {
            return Array(palette.colors.prefix(5))
        }
        return [0.0, 0.12, 0.3, 0.55, 0.75].map { Color(hue: $0, saturation: 0.65, brightness: 0.92) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    HStack {
                        SettingsRowLabel(
                            title: "iCloud Sync",
                            systemImage: "icloud.fill",
                            tint: .blue
                        )
                        Label(
                            isSignedInToICloud ? "On" : "Off",
                            systemImage: isSignedInToICloud ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                        )
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isSignedInToICloud ? Color.green : Color.orange)
                    }
                    .accessibilityElement(children: .combine)

                    if !isSignedInToICloud {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        } label: {
                            SettingsRowLabel(title: "Open Settings", systemImage: "gear", tint: .gray, accessory: .external)
                        }
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text(isSignedInToICloud
                         ? "Your library syncs privately through your iCloud account to your other devices."
                         : "Sign in to iCloud in the Settings app to sync your library across devices. Until then, it's stored only on this device.")
                }

                Section {
                    Button {
                        exportLibrary()
                    } label: {
                        SettingsRowLabel(
                            title: "Export Library",
                            subtitle: "Every color, palette, and tag as a JSON file",
                            systemImage: "square.and.arrow.up",
                            tint: .indigo
                        )
                    }
                    .disabled(libraryIsEmpty)
                } header: {
                    Text("Library")
                }

                Section("Help") {
                    Button {
                        replayOnboarding()
                    } label: {
                        SettingsRowLabel(
                            title: "Replay Onboarding",
                            subtitle: "See the welcome tour again",
                            systemImage: "sparkles",
                            tint: .purple
                        )
                    }
                    Link(destination: AppLinks.supportEmailURL) {
                        SettingsRowLabel(title: "Contact Support", systemImage: "envelope.fill", tint: .green, accessory: .external)
                    }
                }

                Section("Legal") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        SettingsRowLabel(title: "Privacy Policy", systemImage: "hand.raised.fill", tint: .blue)
                    }
                    Link(destination: AppLinks.termsOfUse) {
                        SettingsRowLabel(title: "Terms of Use", systemImage: "doc.text.fill", tint: .gray, accessory: .external)
                    }
                }

                // On its own, last, and away from Export: the one action here
                // that can't be undone.
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete All Data")
                            .frame(maxWidth: .infinity)
                    }
                    .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                        Button("Delete All Data", role: .destructive) { deleteAll() }
                    } message: {
                        Text("This permanently deletes \(deleteScope), your recent searches, and Siri and Spotlight suggestions. If iCloud sync is on, they're also removed from your other devices. This can't be undone.")
                    }
                } footer: {
                    Text("Permanently removes your library from this device and iCloud.")
                }

                #if DEBUG
                Section {
                    Picker("Start at", selection: $debugStart) {
                        ForEach(OnboardingDebug.stepNames, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Toggle("Slow motion (0.25×)", isOn: $debugSlowMo)
                    Picker("Apple Intelligence", selection: $debugAI) {
                        ForEach(OnboardingDebug.AIOverride.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    Button {
                        OnboardingDebug.requestFromSettings(start: debugStart)
                        // Same path as Replay Onboarding: the presenter restarts it in onDismiss.
                        replayOnboarding()
                    } label: {
                        Label("Try Onboarding", systemImage: "play.circle")
                    }
                    Button {
                        debugAI = OnboardingDebug.AIOverride.on.rawValue
                        OnboardingDebug.requestFromSettings(start: "pull")
                        replayOnboarding()
                    } label: {
                        Label("Replay with Apple Intelligence", systemImage: "sparkles")
                    }
                    Button {
                        debugAI = OnboardingDebug.AIOverride.off.rawValue
                        OnboardingDebug.requestFromSettings(start: "pull")
                        replayOnboarding()
                    } label: {
                        Label("Replay without Apple Intelligence", systemImage: "photo")
                    }
                } header: {
                    Text("Onboarding (Debug)")
                } footer: {
                    Text("Starts onboarding at the chosen step with the sample image. Completing it behaves like a normal replay. Apple Intelligence picks the path: On picks a color and generates around it (simulated where the model can't run), Off makes the palette straight from the photo. This device: \(OnboardingPaletteMaker.deviceAIStatus).")
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't export your library.", isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                ForEach(headerColors.indices, id: \.self) { index in
                    Rectangle()
                        .fill(headerColors[index])
                        .padding(.horizontal, -0.5)
                }
            }
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
            .accessibilityHidden(true)

            VStack(spacing: 2) {
                Text("Palettes")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                Text(librarySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Version \(versionString)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    private func exportLibrary() {
        do {
            let data = try appData.libraryExport().jsonData()
            let url = try ExportFiles.write(data, baseName: "palettes-library", ext: "json")
            ShareSheetPresenter.present(items: [url], cleanup: url)
        } catch {
            showExportError = true
        }
    }

    private func replayOnboarding() {
        // The presenter restarts onboarding in the sheet's onDismiss.
        replay.request()
        dismiss()
    }

    private func deleteAll() {
        if appData.deleteAllLibraryData() {
            dismiss()
            ToastManager.shared.show("All data deleted", icon: "trash.fill")
        }
    }
}

/// A Settings row: a tinted icon tile, a title with an optional subtitle and,
/// for links that leave the app, an outbound arrow. Reads in the primary
/// color (not the accent tint buttons and links would otherwise get).
private struct SettingsRowLabel: View {
    enum Accessory {
        case none
        case external
    }

    let title: String
    var subtitle: String? = nil
    let systemImage: String
    let tint: Color
    var accessory: Accessory = .none

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if accessory == .external {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData(inMemory: true))
        .environmentObject(OnboardingReplayCoordinator())
}
