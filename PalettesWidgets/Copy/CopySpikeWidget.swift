//
//  CopySpikeWidget.swift
//  PalettesWidgets
//
//  DEBUG-only experiment: can a widget button write the clipboard without
//  opening the app? Deleted once the answer is recorded in the spec.
//

#if DEBUG
import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct CopySpikeIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Spike"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        let text = "Palettes copy spike \(Date.now.formatted(date: .omitted, time: .standard))"
        await MainActor.run { UIPasteboard.general.string = text }
        return .result()
    }
}

struct CopySpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CopySpikeWidget", provider: QuickCreateProvider()) { _ in
            Button(intent: CopySpikeIntent()) {
                Label("Copy test", systemImage: "doc.on.doc")
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Copy Spike (debug)")
        .supportedFamilies([.systemSmall])
    }
}
#endif
