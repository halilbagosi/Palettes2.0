//
//  SettingsView.swift
//  Palettes
//
//  iCloud status, library export/deletion, privacy policy, and support.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appData: AppData
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("iCloud", value: isSignedInToICloud ? "Signed In" : "Not Signed In")
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
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                    .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                        Button("Delete All Data", role: .destructive) { deleteAll() }
                    } message: {
                        Text("This permanently deletes every color, palette, and tag, your recent searches, and Siri and Spotlight suggestions. If iCloud sync is on, they're also removed from your other devices. This can't be undone.")
                    }
                } header: {
                    Text("Your Data")
                } footer: {
                    Text("Export saves every color, palette, and tag as a JSON file.")
                }

                Section("About") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Link(destination: AppLinks.termsOfUse) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.supportEmailURL) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    Button {
                        replayOnboarding()
                    } label: {
                        Label("Replay Onboarding", systemImage: "sparkles")
                    }
                    LabeledContent("Version", value: versionString)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
        dismiss()
        // The onboarding cover is presented from the app root, so wait for
        // this sheet to finish dismissing before raising it.
        // Written to defaults directly: this view is gone by the time it fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            UserDefaults.standard.set(false, forKey: OnboardingModel.completionKey)
        }
    }

    private func deleteAll() {
        if appData.deleteAllLibraryData() {
            dismiss()
            ToastManager.shared.show("All data deleted", icon: "trash.fill")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData(inMemory: true))
}
