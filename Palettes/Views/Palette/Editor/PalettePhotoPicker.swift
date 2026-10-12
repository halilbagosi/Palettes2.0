//
//  PalettePhotoPicker.swift
//  Palettes
//
//  Scan's full-screen picker: the photo on onboarding's plain stage, with the
//  palette colors that came from it (not those added another way) as a
//  numbered strip under it. One color is selected at a time (the
//  first to begin with); the glass loupe sits where that color was picked, and
//  touching the photo moves it there. Tapping another band moves the loupe to
//  that color. There is nothing to confirm per color: ✓ keeps every move, ✕
//  drops them. Presented full screen, never in a scroll view, so the drag is
//  reliable.
//

import SwiftUI

struct PalettePhotoPicker: View {
    let image: UIImage
    let sampler: ImageColorExtractor.PixelSampler?
    /// The colors that were moved, with their new values, and where every
    /// color now sits on the photo.
    var onDone: (_ picked: [PaletteColor], _ points: [UUID: CGPoint]) -> Void

    private struct Entry {
        var color: PaletteColor
        var point: CGPoint
        var moved = false
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var entries: [Entry]
    @State private var selected = 0
    @State private var dragVelocity: CGSize = .zero

    init(
        image: UIImage,
        sampler: ImageColorExtractor.PixelSampler?,
        colors: [PaletteColor],
        points: [UUID: CGPoint],
        onDone: @escaping ([PaletteColor], [UUID: CGPoint]) -> Void
    ) {
        self.image = image
        self.sampler = sampler
        self.onDone = onDone
        _entries = State(initialValue: colors.map {
            Entry(color: $0, point: points[$0.id] ?? CGPoint(x: 0.5, y: 0.5))
        })
    }

    private var current: Entry? {
        entries.indices.contains(selected) ? entries[selected] : nil
    }

    /// The selected color's hex is another color's too; ✓ keeps that one as it was.
    private var isDuplicate: Bool {
        guard let current else { return false }
        return entries.indices.contains {
            $0 != selected && entries[$0].color.hex.caseInsensitiveCompare(current.color.hex) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let rect = PhotoLoupeGeometry.imageRect(imageSize: image.size, in: geo.size)
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .accessibilityLabel("Photo")
                            .accessibilityHint("Swipe up or down to move the selected color's marker right or left.")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment: nudge(by: 1)
                                case .decrement: nudge(by: -1)
                                @unknown default: break
                                }
                            }

                        if let current {
                            PhotoSampleMarker(color: current.color.color, dragVelocity: dragVelocity)
                                .position(PhotoPinGeometry.position(of: current.point, in: rect))
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragVelocity = value.velocity
                                sample(at: value.location, in: rect)
                            }
                            .onEnded { _ in
                                dragVelocity = .zero
                                nameCurrent()
                            }
                    )
                }

                stripPanel
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
            }
            .background((colorScheme == .light ? Color.white : Color.black).ignoresSafeArea())
            .navigationTitle("Pick Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Label("Cancel", systemImage: "xmark").foregroundStyle(Color.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SheetConfirmButton(kind: .save) { done() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Strip

    private var stripPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current {
                HStack(spacing: 8) {
                    Text(current.color.name.isEmpty ? "Untitled" : current.color.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    // The hex and the notice share one slot, so neither moves the strip.
                    ZStack(alignment: .trailing) {
                        Text(current.color.hex.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .opacity(isDuplicate ? 0 : 1)
                        Label("Already in this palette", systemImage: "info.circle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .opacity(isDuplicate ? 1 : 0)
                    }
                    .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }

            HStack(spacing: 0) {
                ForEach(entries.indices, id: \.self) { index in
                    band(index)
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        // Glass behind the strip, not around it: content inside glass gets a
        // vibrancy treatment that would wash out the badges' grey and blue.
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.clear)
                .liquidGlass(.regular, in: .rect(cornerRadius: 24))
        }
    }

    private func band(_ index: Int) -> some View {
        let entry = entries[index]
        let isSelected = index == selected
        return Button { select(index) } label: {
            Rectangle()
                .fill(entry.color.color)
                .overlay(alignment: .bottom) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(isSelected ? Color.blue : Color.gray))
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
                        .padding(.bottom, 6)
                        .animation(.easeOut(duration: 0.2), value: isSelected)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color \(index + 1), \(entry.color.name)")
        .accessibilityValue(entry.color.hex)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Picking

    /// Selects a color; the loupe glides to where it was picked.
    private func select(_ index: Int) {
        guard index != selected else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.15)) {
            selected = index
        }
    }

    /// Moves the selected color's loupe to `location` (clamped to the photo)
    /// and takes the color under it, 1:1 with no animation.
    private func sample(at location: CGPoint, in rect: CGRect) {
        guard entries.indices.contains(selected) else { return }
        let clamped = CGPoint(
            x: min(max(location.x, rect.minX), rect.maxX),
            y: min(max(location.y, rect.minY), rect.maxY)
        )
        place(PhotoLoupeGeometry.normalizedPoint(in: rect, at: clamped))
    }

    private func place(_ point: CGPoint) {
        let rgb = sampler?.color(at: point, radius: 2)
            ?? ImageColorExtractor.sampleColor(from: image, at: point, radius: 2)
        entries[selected].point = point
        entries[selected].color.hex = ColorAdjustment.hexString(r: rgb.r, g: rgb.g, b: rgb.b)
        entries[selected].color.color = ColorAdjustment.color(r: rgb.r, g: rgb.g, b: rgb.b)
        entries[selected].moved = true
    }

    /// Names follow the color once the finger lifts, not on every drag frame.
    private func nameCurrent() {
        guard entries.indices.contains(selected), entries[selected].moved else { return }
        entries[selected].color.name = ColorNamer.name(forHex: entries[selected].color.hex)
    }

    private func nudge(by direction: Int) {
        guard let current else { return }
        place(PhotoPinGeometry.nudged(current.point, by: direction))
        nameCurrent()
        UIAccessibility.post(notification: .announcement, argument: entries[selected].color.name)
    }

    private func done() {
        onDone(
            entries.filter(\.moved).map(\.color),
            Dictionary(uniqueKeysWithValues: entries.map { ($0.color.id, $0.point) })
        )
        dismiss()
    }
}

#Preview {
    let image = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500)).image { ctx in
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemOrange, .systemPurple]
        for (i, c) in colors.enumerated() {
            c.setFill()
            ctx.fill(CGRect(x: 0, y: CGFloat(i) * 100, width: 400, height: 100))
        }
    }
    let colors = ["#FF3B30", "#34C759", "#007AFF"].map {
        PaletteColor(color: Color(hex: $0) ?? .gray, hex: $0, name: ColorNamer.name(forHex: $0))
    }
    return PalettePhotoPicker(
        image: image,
        sampler: ImageColorExtractor.PixelSampler(image: image),
        colors: colors,
        points: [:],
        onDone: { _, _ in }
    )
}
