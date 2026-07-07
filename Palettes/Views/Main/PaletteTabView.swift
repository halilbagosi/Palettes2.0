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
        .tabBarMinimizeBehavior(.onScrollDown)
        .environmentObject(appData)
    }
}

enum TabValue {
    case palettes, colors, account, search, generate
}

#Preview {
    PaletteTabView()
}
