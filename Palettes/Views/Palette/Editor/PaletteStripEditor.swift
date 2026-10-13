//
//  PaletteStripEditor.swift
//  Palettes
//
//  The palette strip that is the editor: tap a band to edit it, hold and drag
//  to reorder (system drag and drop), and a context menu per band. Colors are
//  added from the add panel under the list, not from the strip. The host
//  (PaletteEditor) owns the draft and what the buttons open.
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Declared under `UTExportedTypeDeclarations` in `AppInfo.plist`.
    static let paletteBand = UTType(exportedAs: "com.halilbagosi.palettes.band")
}

/// What a dragged band carries: just its identity. Dropping resolves it
/// against the draft, so a stale or foreign payload is harmless.
private struct BandDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .paletteBand)
    }
}

struct PaletteStripEditor: View {
    @Binding var draft: PaletteDraft
    /// The band last tapped; the add panel's Harmony source builds on it.
    @Binding var selection: UUID?
    /// Bands that are entering as a first fill, each with its place in the
    /// stagger (empty otherwise).
    var entrance: [UUID: Int] = [:]
    /// Take whatever height the container has (at least `height`) instead of
    /// the fixed `height`: the split layout's tall strip.
    var fillsHeight = false
    var onEdit: (UUID) -> Void
    var onTag: (UUID) -> Void
    /// For the Undo toast.
    var onRemove: (_ index: Int, _ color: PaletteColor) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var targetedID: UUID?
    /// Completed drops, for the release haptic.
    @State private var dropCount = 0
    /// The band being dragged, recorded when the drag starts so the insertion
    /// bar can sit on the side where it will land.
    @State private var draggingID: UUID?
    /// The bar's last position, kept so it can fade out where it was.
    @State private var lastSlot: BarSlot?
    /// False until the bar has a position, so it fades in place instead of
    /// sliding in from the start.
    @State private var barPlaced = false

    private struct BarSlot: Equatable {
        /// Index of the band boundary the bar sits on (0...count).
        var boundary: Int
        /// True when it sits on the target's trailing edge.
        var trailing: Bool
        var ink: Color
    }

    /// Also the height of the empty preview and of Pick's swatch.
    static let height: CGFloat = 72
    private let cornerRadius: CGFloat = 16

    /// The final index (after removal) when band `id` is dropped on band
    /// `targetID`: `id` takes the target's slot and the target shifts away
    /// from the side `id` came from: moving right inserts after T, moving left
    /// inserts before T. `nil` when nothing should move.
    static func dropIndex(moving id: UUID, onto targetID: UUID, in colors: [PaletteColor]) -> Int? {
        guard id != targetID,
              colors.contains(where: { $0.id == id }),
              let target = colors.firstIndex(where: { $0.id == targetID }) else { return nil }
        return target
    }

    /// The drop's settle. Reduce Motion: bands jump (nil), no layout movement.
    private var settle: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.15)
    }

    /// Duplicate and remove: the same timing without the bounce.
    private var reshuffle: Animation? {
        reduceMotion ? nil : .spring(duration: 0.35, bounce: 0)
    }

    private var currentSlot: BarSlot? {
        guard let target = targetedID, let dragging = draggingID, target != dragging,
              let t = draft.colors.firstIndex(where: { $0.id == target }),
              let d = draft.colors.firstIndex(where: { $0.id == dragging }) else { return nil }
        let trailing = d < t
        return BarSlot(boundary: trailing ? t + 1 : t, trailing: trailing, ink: draft.colors[t].color.legibleInk)
    }

    // A BandDragItem dragged from another editor instance shows a bar from the
    // local draggingID, but its drop is rejected (dropIndex finds no such band).
    private func beginDrag(_ id: UUID) -> BandDragItem {
        draggingID = id
        lastSlot = nil
        barPlaced = false
        return BandDragItem(id: id)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(draft.colors) { entry in
                band(entry)
            }
        }
        .frame(minHeight: Self.height, maxHeight: fillsHeight ? .infinity : Self.height)
        // Clear while bands stagger in, so the last color doesn't fill the strip first.
        .background(entrance.isEmpty ? (draft.colors.last?.color ?? Color.clear) : Color.clear)
        .overlay { insertionBar }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .sensoryFeedback(.selection, trigger: targetedID) { _, new in new != nil }
        .sensoryFeedback(.impact(weight: .light), trigger: dropCount)
        .onChange(of: currentSlot) { _, new in
            if let new {
                lastSlot = new
                // Set after this slot's first render, so only later moves slide.
                barPlaced = true
            }
        }
    }

    // MARK: Insertion bar

    /// One bar for the whole strip: it slides between slots (fades under
    /// Reduce Motion) and shows where the dragged band will land.
    private var insertionBar: some View {
        GeometryReader { geo in
            let count = max(draft.colors.count, 1)
            let bandWidth = geo.size.width / CGFloat(count)
            let slot = currentSlot ?? lastSlot
            Rectangle()
                .fill(slot?.ink ?? .clear)
                .frame(width: 3, height: geo.size.height)
                .offset(x: slot.map { CGFloat($0.boundary) * bandWidth - ($0.trailing ? 3 : 0) } ?? 0)
                .animation(barPlaced && !reduceMotion ? .snappy : nil, value: slot)
                // Scoped to opacity so the fade can't drag the offset along.
                .animation(.easeInOut(duration: 0.15)) { $0.opacity(currentSlot == nil ? 0 : 1) }
        }
        .allowsHitTesting(false)
    }

    // MARK: Band

    @ViewBuilder
    private func band(_ entry: PaletteColor) -> some View {
        let ink = entry.color.legibleInk
        let id = entry.id
        let index = draft.colors.firstIndex { $0.id == id } ?? 0
        let isLast = index == draft.colors.count - 1
        let isFirst = index == 0

        ZStack(alignment: .bottom) {
            if let role = entry.role, !role.isEmpty {
                Text(role)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ink.opacity(0.15), in: Capsule())
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
        }
        // minWidth 0: a role capsule can't widen its band past `bandWidth`.
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Overlap neighbors a hairline so antialiasing can't show a seam.
            Rectangle().fill(entry.color).padding(.horizontal, -0.5)
        }
        .overlay {
            if selection == id {
                // The end bands' frames follow the strip's rounded corners.
                UnevenRoundedRectangle(
                    topLeadingRadius: isFirst ? cornerRadius : 0,
                    bottomLeadingRadius: isFirst ? cornerRadius : 0,
                    bottomTrailingRadius: isLast ? cornerRadius : 0,
                    topTrailingRadius: isLast ? cornerRadius : 0,
                    style: .continuous
                )
                .strokeBorder(ink, lineWidth: 3)
                .allowsHitTesting(false)
            }
        }
        .firstFillEntrance(index: entrance[id])
        .contentShape(Rectangle())
        .onTapGesture {
            selection = id
            onEdit(id)
        }
        .draggable(beginDrag(id)) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(entry.color)
                .frame(width: 64, height: Self.height)
        }
        .dropDestination(for: BandDragItem.self) { items, _ in
            draggingID = nil
            guard let dropped = items.first,
                  let to = Self.dropIndex(moving: dropped.id, onto: id, in: draft.colors) else { return false }
            withAnimation(settle) { draft.move(id: dropped.id, to: to) }
            dropCount += 1
            return true
        } isTargeted: { isTargeted in
            if isTargeted {
                targetedID = id
            } else if targetedID == id {
                targetedID = nil
            }
        }
        .contextMenu {
            Button { selection = id; onEdit(id) } label: { Label("Edit", systemImage: "pencil") }
            Button { duplicate(id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button { onTag(id) } label: { Label("Tag…", systemImage: "tag") }
            Button(role: .destructive) { remove(id) } label: { Label("Remove", systemImage: "trash") }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.name), \(entry.hex)")
        .accessibilityValue(entry.role ?? "")
        .accessibilityHint("Double-tap to edit")
        .accessibilityAddTraits(selection == id ? [.isButton, .isSelected] : .isButton)
        .accessibilityActions {
            if index > 0 {
                Button("Move Left") { draft.move(id: id, to: index - 1) }
            }
            if !isLast {
                Button("Move Right") { draft.move(id: id, to: index + 1) }
            }
            Button("Duplicate") { duplicate(id) }
            Button("Tag") { onTag(id) }
            Button("Remove") { remove(id) }
        }
    }

    private func duplicate(_ id: UUID) {
        withAnimation(reshuffle) { draft.duplicate(id: id) }
    }

    private func remove(_ id: UUID) {
        var removed: (index: Int, color: PaletteColor)?
        withAnimation(reshuffle) { removed = draft.remove(id: id) }
        guard let removed else { return }
        if selection == id { selection = nil }
        onRemove(removed.index, removed.color)
    }
}

#Preview {
    @Previewable @State var draft = PaletteDraft(name: "Dusk", colors: [
        PaletteColor(color: Color(hex: "#264653") ?? .gray, hex: "#264653", name: "Charcoal Blue", role: "Primary"),
        PaletteColor(color: Color(hex: "#2A9D8F") ?? .gray, hex: "#2A9D8F", name: "Persian Green"),
        PaletteColor(color: Color(hex: "#E9C46A") ?? .gray, hex: "#E9C46A", name: "Saffron", role: "Accent"),
        PaletteColor(color: Color(hex: "#F4A261") ?? .gray, hex: "#F4A261", name: "Sandy Brown"),
        PaletteColor(color: Color(hex: "#E76F51") ?? .gray, hex: "#E76F51", name: "Burnt Sienna"),
    ])
    @Previewable @State var selection: UUID?

    PaletteStripEditor(
        draft: $draft,
        selection: $selection,
        onEdit: { _ in },
        onTag: { _ in },
        onRemove: { _, _ in }
    )
    .padding()
}
