//
//  ExportPaletteSheet.swift
//  Palettes
//
//  Export sheet: the palette up top, every format as a grouped chip, a
//  file-style preview of the result, and the action that fits the format
//  (copy code, copy a link, or share a file).
//

import SwiftUI
import UIKit

struct ExportPaletteSheet: View {
    let palette: PaletteViewModel

    @State private var selectedFormat: PaletteExportFormat = .css
    /// Bumped on every copy; drives the haptic and the "Copied" label.
    @State private var copyCount = 0
    @State private var showsCopied = false
    @Environment(\.dismiss) private var dismiss

    private var output: String {
        PaletteExporter.export(palette, as: selectedFormat)
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

    private var fileName: String {
        selectedFormat == .tailwind ? "tailwind.config.js" : "\(slugifiedPaletteName).\(selectedFormat.fileExtension)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                        .padding(.horizontal)
                    formatPicker
                    previewCard
                        .padding(.horizontal)
                }
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .bottomActionBar { actionBar }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .softScrollEdge()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCancelButton { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: copyCount)
            .onChange(of: selectedFormat) { showsCopied = false }
            #if DEBUG
            .onAppear {
                if ScreenshotSeed.isActive,
                   let raw = UserDefaults.standard.string(forKey: "screenshotExportFormat"),
                   let format = PaletteExportFormat(rawValue: raw) {
                    selectedFormat = format
                }
            }
            #endif
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PaletteStrip(colors: palette.colors, height: 52, cornerRadius: 14)
            HStack(alignment: .firstTextBaseline) {
                Text(palette.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(palette.paletteColors.count) \(palette.paletteColors.count == 1 ? "color" : "colors")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Formats

    private var formatPicker: some View {
        ScrollViewReader { proxy in
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(ExportFormatGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        HStack(spacing: 8) {
                            ForEach(group.formats) { format in
                                FormatChip(format: format, isSelected: format == selectedFormat) {
                                    withAnimation(.snappy(duration: 0.25)) { selectedFormat = format }
                                }
                                .id(format)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        // Keep the selected chip in view, including one picked off-screen.
        .onChange(of: selectedFormat) { _, format in
            withAnimation(.snappy) { proxy.scrollTo(format, anchor: .center) }
        }
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: selectedFormat.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .lineLimit(1)
                    Text(selectedFormat.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)

            Divider()

            if selectedFormat.sharesAsFile {
                FilePreview(palette: palette, format: selectedFormat)
            } else {
                CodePreview(text: output)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.25), value: selectedFormat)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 12) {
            if selectedFormat.sharesAsFile {
                if !selectedFormat.isBinary {
                    copyButton(prominent: false)
                }
                Button {
                    shareCurrentFormat()
                } label: {
                    Label("Share File", systemImage: "square.and.arrow.up")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .glassButton(prominent: true)
            } else {
                copyButton(prominent: true)
                Button {
                    shareCurrentFormat()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .glassButton()
            }
        }
        .controlSize(.large)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func copyButton(prominent: Bool) -> some View {
        Button {
            UIPasteboard.general.string = output
            copyCount += 1
            showsCopied = true
            let count = copyCount
            Task {
                try? await Task.sleep(for: .seconds(1.6))
                if copyCount == count { showsCopied = false }
            }
        } label: {
            Label(showsCopied ? "Copied" : selectedFormat.copyTitle,
                  systemImage: showsCopied ? "checkmark" : "doc.on.doc")
                .fontWeight(.semibold)
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity)
        }
        .glassButton(prominent: prominent)
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

// MARK: - Format metadata

/// How the sheet groups formats into chip rows.
private enum ExportFormatGroup: String, CaseIterable, Identifiable {
    case code, files, quick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code: "Code"
        case .files: "Design Files"
        case .quick: "Quick Share"
        }
    }

    var formats: [PaletteExportFormat] {
        switch self {
        case .code: [.css, .scss, .tailwind, .swiftui, .json]
        case .files: [.svg, .ase, .pdf]
        case .quick: [.plainHex, .coolorsURL]
        }
    }
}

private extension PaletteExportFormat {
    var chipTitle: String {
        switch self {
        case .plainHex: "HEX List"
        case .coolorsURL: "Link"
        case .ase: "ASE"
        default: displayName
        }
    }

    var symbol: String {
        switch self {
        case .css: "curlybraces"
        case .scss: "dollarsign"
        case .tailwind: "wind"
        case .swiftui: "swift"
        case .json: "curlybraces.square"
        case .svg: "square.on.circle"
        case .ase: "swatchpalette"
        case .pdf: "doc.richtext"
        case .plainHex: "number"
        case .coolorsURL: "link"
        }
    }

    var summary: String {
        switch self {
        case .css: "Custom properties for any web project"
        case .scss: "Sass variables, named by role"
        case .tailwind: "Colors for theme.extend in your Tailwind config"
        case .swiftui: "A Color extension to drop into Xcode"
        case .json: "Names, hex values and roles"
        case .svg: "Vector swatches for Figma, Sketch and Illustrator"
        case .ase: "Adobe Swatch Exchange for Photoshop, Illustrator and Procreate"
        case .pdf: "A printable palette sheet"
        case .plainHex: "One hex value per line"
        case .coolorsURL: "A shareable link to this palette on Coolors"
        }
    }

    var fileExtension: String {
        switch self {
        case .css: "css"
        case .scss: "scss"
        case .tailwind: "js"
        case .swiftui: "swift"
        case .json: "json"
        case .svg: "svg"
        case .ase: "ase"
        case .pdf: "pdf"
        case .plainHex: "txt"
        case .coolorsURL: "url"
        }
    }

    /// True when the natural way out is a file (Share File leads).
    var sharesAsFile: Bool {
        self == .svg || isBinary
    }

    var copyTitle: String {
        switch self {
        case .coolorsURL: "Copy Link"
        case .plainHex: "Copy HEX"
        default: "Copy \(displayName)"
        }
    }
}

// MARK: - Pieces

private struct FormatChip: View {
    let format: PaletteExportFormat
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(format.chipTitle, systemImage: format.symbol)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .tertiarySystemFill)))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(format.summary)
    }
}

/// Monospaced, line-numbered code with a color dot before every hex value.
private struct CodePreview: View {
    let text: String

    private var lines: [String] {
        text.components(separatedBy: "\n")
    }

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(index + 1)")
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 18, alignment: .trailing)
                        Self.highlighted(line)
                    }
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .fixedSize()
            .textSelection(.enabled)
            .padding(14)
        }
        .scrollIndicators(.hidden)
    }

    private static let hexPattern = /#[0-9A-Fa-f]{6}\b/

    /// The line as one `Text`, with a filled dot in the color before each hex.
    static func highlighted(_ line: String) -> Text {
        var result = Text("")
        var rest = line[...]
        while let match = rest.firstMatch(of: hexPattern) {
            result = result + Text(rest[..<match.range.lowerBound])
            let hex = String(match.output)
            if let color = Color(hex: hex) {
                result = result + Text(Image(systemName: "circle.fill")).foregroundStyle(color) + Text("\u{2009}")
            }
            result = result + Text(hex).fontWeight(.semibold)
            rest = rest[match.range.upperBound...]
        }
        return result + Text(rest)
    }
}

/// A document thumbnail for formats that only exist as files.
private struct FilePreview: View {
    let palette: PaletteViewModel
    let format: PaletteExportFormat

    private var title: String {
        switch format {
        case .ase: "Swatch file"
        case .pdf: "PDF document"
        default: "Vector file"
        }
    }

    private var byteCount: String {
        let data: Data
        switch format {
        case .ase: data = PaletteExporter.aseData(palette)
        case .pdf: data = PaletteExporter.pdfData(palette)
        default: data = Data(PaletteExporter.export(palette, as: format).utf8)
        }
        return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    var body: some View {
        HStack(spacing: 18) {
            VStack(spacing: 0) {
                PaletteStrip(colors: palette.colors, height: 46, cornerRadius: 0)
                Spacer(minLength: 0)
                Text(format.fileExtension.uppercased())
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10)
            }
            .frame(width: 76, height: 96)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text("\(palette.paletteColors.count) swatches · \(byteCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Share it to Files, AirDrop or straight into another app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
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
