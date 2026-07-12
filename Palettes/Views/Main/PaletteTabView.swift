//
//  SwiftUIView.swift
//  Palettes
//
//  Created by Halil Bagosi on 13.2.26.
//

import SwiftUI

struct PaletteTabView: View {

    @StateObject private var appData = AppData()

    var body: some View {
        TabView(selection: $appData.activeTab) {
            Tab("Palettes", systemImage: "swatchpalette.fill", value: .palettes) {
                PaletteView()
            }

            Tab("Colors", systemImage: "circle.grid.cross.fill", value: .colors) {
                ColorsView()
            }

            Tab("Generate", systemImage: "sparkles", value: .generate) {
                GenerateView()
            }

            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .scrollEdgeEffectHidden(false, for: .all)
        .scrollEdgeEffectStyle(.soft, for: .all)
        .environmentObject(appData)
        .background { tabShortcuts }
    }

    /// Hidden buttons providing ⌘1–⌘4 tab switching for iPad keyboards.
    private var tabShortcuts: some View {
        Group {
            Button("") { appData.activeTab = .palettes }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { appData.activeTab = .colors }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { appData.activeTab = .generate }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { appData.activeTab = .search }
                .keyboardShortcut("4", modifiers: .command)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

enum TabValue {
    case palettes, colors, account, search, generate
}

#Preview {
    PaletteTabView()
}
