//
//  IntentSnippets.swift
//  Palettes
//
//  Compact SwiftUI views shown inside Siri / Shortcuts result snippets.
//

import SwiftUI

@available(iOS 26.0, *)
struct PaletteSnippetView: View {
    let name: String
    let hexCodes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(name)
                .font(.headline)
            HStack(spacing: 6) {
                ForEach(Array(hexCodes.enumerated()), id: \.offset) { _, hex in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(height: 44)
                }
            }
        }
        .padding()
    }
}

@available(iOS 26.0, *)
struct ColorSnippetView: View {
    let name: String
    let hex: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: hex) ?? .gray)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(hex).font(.subheadline.monospaced()).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }
}
