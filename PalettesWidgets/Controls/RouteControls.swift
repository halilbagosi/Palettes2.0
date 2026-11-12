//
//  RouteControls.swift
//  PalettesWidgets
//
//  Control Center, Lock Screen and Action button controls (iOS 18+). Each
//  opens Palettes on a creation flow through OpenLinkIntent.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct NewColorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewColorControl") {
            ControlWidgetButton(action: OpenLinkIntent(.newColor)) {
                Label("New Color", systemImage: "plus.circle")
            }
        }
        .displayName("New Color")
    }
}

@available(iOS 18.0, *)
struct NewPaletteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewPaletteControl") {
            ControlWidgetButton(action: OpenLinkIntent(.newPalette)) {
                Label("New Palette", systemImage: "swatchpalette")
            }
        }
        .displayName("New Palette")
    }
}

@available(iOS 18.0, *)
struct ScanColorControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanColorControl") {
            ControlWidgetButton(action: OpenLinkIntent(.scanColor)) {
                Label("Scan Color", systemImage: "eyedropper")
            }
        }
        .displayName("Scan Color")
    }
}

@available(iOS 18.0, *)
struct ScanPaletteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanPaletteControl") {
            ControlWidgetButton(action: OpenLinkIntent(.scanPalette)) {
                Label("Scan Palette", systemImage: "viewfinder")
            }
        }
        .displayName("Scan Palette")
    }
}
