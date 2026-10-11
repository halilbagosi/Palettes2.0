//
//  PrivacyPolicyView.swift
//  Palettes
//
//  Renders the bundled PrivacyPolicy.md so the policy is reachable in-app
//  even offline. Block-level parsing is limited to what the policy uses:
//  `#`/`##` headings and blank-line-separated paragraphs (inline markdown
//  such as **bold** is rendered by Text).
//

import SwiftUI

enum PrivacyPolicy {
    enum Block: Equatable, Hashable {
        case heading(String, level: Int)
        case paragraph(String)
    }

    static func load(bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: "PrivacyPolicy", withExtension: "md") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func blocks(from markdown: String) -> [Block] {
        markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { chunk in
                if chunk.hasPrefix("## ") { return .heading(String(chunk.dropFirst(3)), level: 2) }
                if chunk.hasPrefix("# ") { return .heading(String(chunk.dropFirst(2)), level: 1) }
                return .paragraph(chunk)
            }
    }
}

struct PrivacyPolicyView: View {
    private let blocks = PrivacyPolicy.blocks(from: PrivacyPolicy.load() ?? "")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if blocks.isEmpty {
                    Text("The privacy policy couldn't be loaded. Contact \(AppLinks.supportEmail).")
                }
                ForEach(blocks, id: \.self) { block in
                    switch block {
                    case .heading(let text, let level):
                        Text(text)
                            .font(level == 1 ? .title2.bold() : .headline)
                            .padding(.top, level == 1 ? 0 : 6)
                            .accessibilityAddTraits(.isHeader)
                    case .paragraph(let text):
                        Text((try? AttributedString(
                            markdown: text,
                            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                        )) ?? AttributedString(text))
                        .font(.body)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
