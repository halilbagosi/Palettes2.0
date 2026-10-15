//
//  RolePickerSheet.swift
//  Palettes
//
//  Lets the user tag a palette color with a role: one of the built-in
//  `ColorRole.defaults`, or an app-wide custom tag (`AppData.customTags`).
//  Enforces one-role-per-palette uniqueness: assigning a role that's already
//  held by another color in the same palette clears it there first. Mutates
//  `appData.palettes` directly by index — the same palette-update path
//  `PaletteEditSheet` uses for editing a palette color's hex/name/color. The
//  list UI itself lives in `RoleList`, which only reports the choice back here.
//

import SwiftUI

struct RolePickerSheet: View {
    let currentRole: String?
    let palette: PaletteViewModel
    let colorIndex: Int

    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) var dismiss

    private var paletteIndex: Int? {
        appData.palettes.firstIndex(where: { $0.id == palette.id })
    }

    /// The color's role read live from `appData`, so the checkmark and the
    /// "Remove Tag" section stay in sync as soon as a selection is made,
    /// without needing to dismiss and reopen the sheet.
    private var liveCurrentRole: String? {
        guard let idx = paletteIndex, colorIndex < appData.palettes[idx].paletteColors.count else {
            return currentRole
        }
        return appData.palettes[idx].paletteColors[colorIndex].role
    }

    var body: some View {
        NavigationStack {
            RoleList(current: liveCurrentRole, onSelect: assign(role:))
                .navigationTitle("Tag Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    /// Assigns `role` to `colorIndex` in the palette. If another color in the
    /// same palette already holds `role`, that color is cleared first so a
    /// role only ever has one holder per palette.
    ///
    /// The sheet is dismissed *before* the mutation is applied, and the
    /// mutation itself is deferred until after the dismissal animation
    /// finishes. `RoleBadge`'s scale+opacity transition on
    /// `PaletteDetailView` (see its `.animation(value: role)`) only plays
    /// when the state change lands on a visible view — applying it while
    /// this sheet still covers the detail view makes SwiftUI snap it in
    /// flat instead of animating it in. `paletteIndex`/`colorIndex` are
    /// re-validated after the delay since the palette's colors can change
    /// while the sheet is closing.
    private func assign(role: String?) {
        guard let idx = paletteIndex, colorIndex < appData.palettes[idx].paletteColors.count else { return }

        dismiss()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))

            guard let idx = paletteIndex,
                  colorIndex >= 0,
                  colorIndex < appData.palettes[idx].paletteColors.count else { return }

            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if let role {
                    for j in appData.palettes[idx].paletteColors.indices where j != colorIndex {
                        if appData.palettes[idx].paletteColors[j].role?.caseInsensitiveCompare(role) == .orderedSame {
                            appData.palettes[idx].paletteColors[j].role = nil
                        }
                    }
                }

                appData.palettes[idx].paletteColors[colorIndex].role = role
            }
        }
    }
}

#Preview {
    RolePickerSheet(
        currentRole: "Primary",
        palette: PaletteViewModel(
            name: "Preview Palette",
            colors: [.red, .blue],
            hexCodes: ["#FF0000", "#0000FF"],
            colorNames: ["Red", "Blue"],
            colorRoles: ["Primary", ""]
        ),
        colorIndex: 0
    )
    .environmentObject(AppData(inMemory: true))
}
