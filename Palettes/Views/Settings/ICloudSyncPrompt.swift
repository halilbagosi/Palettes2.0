//
//  ICloudSyncPrompt.swift
//  Palettes
//
//  The one-time "Sync with iCloud?" question after onboarding, and the
//  "merge or replace?" follow-up shared with the Settings toggle.
//

import SwiftUI
import UIKit

extension View {
    /// Asks once, after onboarding, whether to sync with iCloud.
    /// `isReady` is false while something (onboarding) covers the screen.
    func iCloudSyncPrompt(appData: AppData, isReady: Bool) -> some View {
        modifier(ICloudSyncPromptModifier(appData: appData, isReady: isReady))
    }

    /// The "merge or replace?" alert for turning sync on with a library on
    /// this device. `onCancel` runs when the user backs out.
    func iCloudMergeChoice(appData: AppData, isPresented: Binding<Bool>,
                           onCancel: @escaping () -> Void = {}) -> some View {
        modifier(ICloudMergeChoiceModifier(appData: appData, isPresented: isPresented, onCancel: onCancel))
    }
}

enum ICloudSyncCopy {
    /// "iPhone" or "iPad".
    static var device: String { UIDevice.current.model }

    static let promptTitle = "Sync with iCloud?"
    static let promptMessage = "Keep your palettes, colors, and tags up to date on every device signed in to your iCloud account. You can change this anytime in Settings."
    static let mergeTitle = "Merge with iCloud?"
    static var mergeMessage: String {
        "This \(device) already has palettes or colors. Merge them with your iCloud library, or replace them with what's in iCloud?"
    }
    static let turnOffTitle = "Turn Off iCloud Sync?"
    static var turnOffMessage: String {
        "Your library stays on this \(device), but changes will no longer sync. Copies already in iCloud stay on your other devices."
    }
}

private struct ICloudSyncPromptModifier: ViewModifier {
    @ObservedObject var appData: AppData
    let isReady: Bool

    @AppStorage(OnboardingKeys.didComplete) private var onboardingComplete = false
    @AppStorage(ICloudSync.promptAnsweredKey) private var answered = false
    @State private var showQuestion = false
    @State private var showMerge = false
    @State private var task: Task<Void, Never>?

    private var wanted: Bool {
        isReady && ICloudSync.shouldPrompt(onboardingComplete: onboardingComplete, alreadyAnswered: answered)
    }

    func body(content: Content) -> some View {
        content
            .alert(ICloudSyncCopy.promptTitle, isPresented: $showQuestion) {
                Button("Not Now", role: .cancel) {
                    answered = true
                    appData.setICloudSync(enabled: false)
                }
                Button("Turn On") {
                    answered = true
                    turnOn()
                }
            } message: {
                Text(ICloudSyncCopy.promptMessage)
            }
            .iCloudMergeChoice(appData: appData, isPresented: $showMerge)
            .onAppear { schedule() }
            .onChange(of: wanted) { _, _ in schedule() }
    }

    /// Waits for the onboarding cover to finish leaving: an alert asked for
    /// mid-dismissal is dropped.
    private func schedule() {
        task?.cancel()
        guard wanted else { return }
        task = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled, wanted else { return }
            showQuestion = true
        }
    }

    private func turnOn() {
        let hasLibrary = !appData.colors.isEmpty || !appData.palettes.isEmpty
        if appData.storeMode == .local, hasLibrary {
            // One alert has to finish leaving before the next can show.
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                showMerge = true
            }
        } else {
            appData.setICloudSync(enabled: true)
        }
    }
}

private struct ICloudMergeChoiceModifier: ViewModifier {
    @ObservedObject var appData: AppData
    @Binding var isPresented: Bool
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content.alert(ICloudSyncCopy.mergeTitle, isPresented: $isPresented) {
            Button("Merge") {
                appData.setICloudSync(enabled: true, choice: .merge)
            }
            Button("Replace with iCloud", role: .destructive) {
                appData.setICloudSync(enabled: true, choice: .replaceWithICloud)
            }
            Button("Cancel", role: .cancel) { onCancel() }
        } message: {
            Text(ICloudSyncCopy.mergeMessage)
        }
    }
}
