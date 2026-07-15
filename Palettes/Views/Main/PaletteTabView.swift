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
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
            }
        }
        .environmentObject(appData)
        .background { tabShortcuts }
    }

    // MARK: - iOS 18+ (Tab builder, sidebar-adaptable, Liquid Glass chrome on 26)

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $appData.activeTab) {
            Tab("Palettes", systemImage: "swatchpalette.fill", value: TabValue.palettes) {
                PaletteView()
            }

            Tab("Colors", systemImage: "circle.grid.cross.fill", value: TabValue.colors) {
                ColorsView()
            }

            // AI generation relies on Apple Intelligence (iOS 26 only).
            if #available(iOS 26.0, *) {
                Tab("Generate", systemImage: "sparkles", value: TabValue.generate) {
                    GenerateView()
                }
            }

            Tab(value: TabValue.search, role: .search) {
                SearchView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarLiquidGlassChrome()
    }

    // MARK: - iOS 17 (classic tab bar; no Generate tab)

    private var legacyTabView: some View {
        TabView(selection: $appData.activeTab) {
            PaletteView()
                .tabItem { Label("Palettes", systemImage: "swatchpalette.fill") }
                .tag(TabValue.palettes)

            ColorsView()
                .tabItem { Label("Colors", systemImage: "circle.grid.cross.fill") }
                .tag(TabValue.colors)

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(TabValue.search)
        }
    }

    /// Hidden buttons providing ⌘1–⌘4 tab switching for iPad keyboards.
    private var tabShortcuts: some View {
        Group {
            Button("") { appData.activeTab = .palettes }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { appData.activeTab = .colors }
                .keyboardShortcut("2", modifiers: .command)
            if #available(iOS 26.0, *) {
                Button("") { appData.activeTab = .generate }
                    .keyboardShortcut("3", modifiers: .command)
            }
            Button("") { appData.activeTab = .search }
                .keyboardShortcut("4", modifiers: .command)
        }
        .opacity(0)
        .accessibilityHidden(true)
    }
}

enum TabValue {
    case palettes, colors, search, generate
}

extension View {
    /// iOS 26 tab-bar Liquid Glass chrome; a no-op on earlier systems.
    @ViewBuilder
    func tabBarLiquidGlassChrome() -> some View {
        if #available(iOS 26.0, *) {
            self
                .tabBarMinimizeBehavior(.onScrollDown)
                .scrollEdgeEffectHidden(false, for: .all)
                .scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

#Preview {
    PaletteTabView()
}
