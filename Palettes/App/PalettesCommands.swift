//
//  PalettesCommands.swift
//  Palettes
//
//  Menu-bar commands (iPadOS 26 menu bar; the ⌘-hold shortcut overlay on
//  earlier iPadOS). Each acts on the focused window through `SceneCommands`,
//  so a shortcut works whatever tab or library state that window is in.
//

import SwiftUI

struct PalettesCommands: Commands {
    @FocusedValue(\.sceneCommands) private var scene
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Palette") { scene?.newPalette() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(scene == nil)
            Button("New Color") { scene?.newColor() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(scene == nil)
            if supportsMultipleWindows {
                Divider()
                Button("New Window") { openWindow(id: PalettesScene.libraryID) }
                    .keyboardShortcut("n", modifiers: [.command, .option])
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { scene?.showSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .disabled(scene == nil)
        }

        CommandGroup(before: .sidebar) {
            Button("Palettes") { scene?.selectTab(.palettes) }
                .keyboardShortcut("1", modifiers: .command)
                .disabled(scene == nil)
            Button("Colors") { scene?.selectTab(.colors) }
                .keyboardShortcut("2", modifiers: .command)
                .disabled(scene == nil)
            if scene?.canGenerate ?? false {
                Button("Generate") { scene?.selectTab(.generate) }
                    .keyboardShortcut("3", modifiers: .command)
            }
            Button("Search") { scene?.selectTab(.search) }
                .keyboardShortcut("4", modifiers: .command)
                .disabled(scene == nil)
            Divider()
        }
    }
}

enum PalettesScene {
    /// The library window's id, so "New Window" can open another one.
    static let libraryID = "library"
}
