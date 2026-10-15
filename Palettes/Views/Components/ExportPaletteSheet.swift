//
//  ExportPaletteSheet.swift
//  Palettes
//
//  Coolors-style export sheet: pick a format, preview it, copy or share.
//

import SwiftUI
import UIKit

struct ExportPaletteSheet: View {
    let palette: PaletteViewModel

    @State private var selectedFormat: PaletteExportFormat = .css
    @Environment(\.dismiss) private var dismiss

    private var output: String {
        PaletteExporter.export(palette, as: selectedFormat)
    }

    private var binaryPreviewLabel: String {
        switch selectedFormat {
        case .ase: return "Binary format — share as file"
        case .pdf: return "PDF document — share as file"
        default: return ""
        }
    }

    private var slugifiedPaletteName: String {
        let lowered = palette.name.lowercased()
        var result = ""
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                result.append(ch)
            } else if ch == " " {
                result.append("-")
            }
        }
        return result.isEmpty ? "palette" : result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(PaletteExportFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                ScrollView {
                    if selectedFormat.isBinary {
                        Text(binaryPreviewLabel)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal)

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = output
                        ToastManager.shared.show("Copied", icon: "doc.on.doc")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton()
                    .disabled(selectedFormat.isBinary)

                    Button {
                        shareCurrentFormat()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .glassButton(prominent: true)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .navigationTitle("Export Palette")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Share

    private func shareCurrentFormat() {
        switch selectedFormat {
        case .svg:
            if let url = try? ExportFiles.write(Data(output.utf8), baseName: slugifiedPaletteName, ext: "svg") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            } else {
                ShareSheetPresenter.present(items: [output])
            }
        case .ase:
            // No text fallback for binary formats; nothing to share on failure.
            if let url = try? ExportFiles.write(PaletteExporter.aseData(palette), baseName: slugifiedPaletteName, ext: "ase") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            }
        case .pdf:
            if let url = try? ExportFiles.write(PaletteExporter.pdfData(palette), baseName: slugifiedPaletteName, ext: "pdf") {
                ShareSheetPresenter.present(items: [url], cleanup: url)
            }
        default:
            ShareSheetPresenter.present(items: [output])
        }
    }
}

#Preview {
    ExportPaletteSheet(
        palette: PaletteViewModel(
            name: "Neon Nights",
            colors: [.purple, .pink, .orange],
            hexCodes: ["#800080", "#FFC0CB", "#FFA500"],
            colorNames: ["Purple", "Pink", "Orange"]
        )
    )
}
