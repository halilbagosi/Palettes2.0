import Testing
import SwiftUI
@testable import Palettes

@MainActor
struct PaletteDraftTests {
    private func pc(_ hex: String, _ name: String = "", role: String? = nil) -> PaletteColor {
        PaletteColor(color: Color(hex: hex) ?? .gray, hex: hex, name: name, role: role)
    }

    @Test func appendSkipsDuplicateHexesCaseInsensitively() {
        var draft = PaletteDraft(colors: [pc("#FF0000")])
        let added = draft.append([pc("#ff0000"), pc("#00FF00"), pc("#00FF00")])
        #expect(added == 1)
        #expect(draft.colors.map(\.hex) == ["#FF0000", "#00FF00"])
    }

    @Test func replacePutsNewColorsWhereTheOldOnesStarted() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#AA0000"), pc("#222222"), pc("#BB0000")])
        let old: Set<UUID> = [draft.colors[1].id, draft.colors[3].id]
        let result = draft.replace(old, with: [pc("#00AA00"), pc("#00BB00")])
        #expect(result.index == 1)
        #expect(result.added == 2)
        #expect(draft.colors.map(\.hex) == ["#111111", "#00AA00", "#00BB00", "#222222"])
    }

    @Test func replaceSkipsHexesTheRestAlreadyHas() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#AA0000")])
        let result = draft.replace([draft.colors[1].id], with: [pc("#111111"), pc("#aa0000")])
        // The old color is gone, so its own hex may come back; the kept one's may not.
        #expect(result.added == 1)
        #expect(draft.colors.map(\.hex) == ["#111111", "#aa0000"])
    }

    @Test func replaceAppendsWhenTheOldColorsAreGone() {
        var draft = PaletteDraft(colors: [pc("#111111")])
        let result = draft.replace([UUID()], with: [pc("#222222")])
        #expect(result.index == 1)
        #expect(draft.colors.map(\.hex) == ["#111111", "#222222"])
    }

    @Test func canSaveNeedsTwoColors() {
        var draft = PaletteDraft()
        #expect(!draft.canSave)
        _ = draft.append([pc("#111111"), pc("#222222")])
        #expect(draft.canSave)
    }

    @Test func moveByIDReorders() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#222222"), pc("#333333")])
        let first = draft.colors[0].id
        draft.move(id: first, to: 2)
        #expect(draft.colors.map(\.hex) == ["#222222", "#333333", "#111111"])
    }

    @Test func removeReturnsIndexForUndo() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#222222")])
        let id = draft.colors[1].id
        let removed = draft.remove(id: id)
        #expect(removed?.index == 1)
        #expect(draft.colors.count == 1)
    }

    @Test func duplicateInsertsAfterWithUniqueHex() {
        var draft = PaletteDraft(colors: [pc("#808080", "Gray"), pc("#000000")])
        draft.duplicate(id: draft.colors[0].id)
        #expect(draft.colors.count == 3)
        #expect(draft.colors[1].name == "Gray")
        #expect(draft.colors[1].hex != "#808080")
        #expect(Set(draft.colors.map(\.hex)).count == 3)
    }

    @Test func setRoleKeepsOneHolderPerRole() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "Primary"), pc("#222222")])
        draft.setRole("primary", for: draft.colors[1].id)
        #expect(draft.colors[0].role == nil)
        #expect(draft.colors[1].role == "primary")
    }

    @Test func reinsertRestoresPositionAndRole() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#333333")])
        let restored = draft.reinsert(pc("#222222", role: "Accent"), at: 1)
        #expect(restored == true)
        #expect(draft.colors.map(\.hex) == ["#111111", "#222222", "#333333"])
        #expect(draft.colors[1].role == "Accent")
    }

    @Test func reinsertDropsRoleAnotherColorNowHolds() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "accent")])
        draft.reinsert(pc("#222222", role: "Accent"), at: 0)
        #expect(draft.colors.map(\.hex) == ["#222222", "#111111"])
        #expect(draft.colors[0].role == nil)
        #expect(draft.colors[1].role == "accent")
    }

    @Test func reinsertSkipsAHexThatIsBackInThePalette() {
        var draft = PaletteDraft(colors: [pc("#111111")])
        let restored = draft.reinsert(pc("#111111"), at: 0)
        #expect(restored == false)
        #expect(draft.colors.count == 1)
    }

    @Test func reinsertClampsTheIndex() {
        var draft = PaletteDraft(colors: [pc("#111111")])
        draft.reinsert(pc("#222222"), at: 9)
        #expect(draft.colors.map(\.hex) == ["#111111", "#222222"])
    }

    @Test func resolvedNameFallsBackToSuggestionThenUntitled() {
        #expect(PaletteDraft(name: "  Dusk ").resolvedName(suggestion: "Ocean") == "Dusk")
        #expect(PaletteDraft(name: " ").resolvedName(suggestion: "Ocean") == "Ocean")
        #expect(PaletteDraft().resolvedName(suggestion: "") == "Untitled Palette")
    }

    @Test func finalizedColorsNamesBlankEntries() {
        let draft = PaletteDraft(colors: [pc("#FF0000", "  ")])
        #expect(draft.finalizedColors()[0].name == ColorNamer.name(forHex: "#FF0000"))
    }

    @Test func initFromPaletteCopiesNameAndColors() {
        let palette = PaletteViewModel(name: "P", paletteColors: [pc("#111111", role: "Primary"), pc("#222222")])
        let draft = PaletteDraft(palette: palette)
        #expect(draft.name == "P")
        #expect(draft.colors == palette.paletteColors)
        var edited = draft
        edited.name = "Q"
        #expect(edited != draft)   // drives Cancel's "Discard changes?" check
    }

    @Test func moveClampsOutOfRangeIndex() {
        var draft = PaletteDraft(colors: [pc("#111111"), pc("#222222"), pc("#333333")])
        draft.move(id: draft.colors[0].id, to: 99)
        #expect(draft.colors.map(\.hex) == ["#222222", "#333333", "#111111"])
        draft.move(id: draft.colors[2].id, to: -5)
        #expect(draft.colors.map(\.hex) == ["#111111", "#222222", "#333333"])
    }

    @Test func removeUnknownIDReturnsNil() {
        var draft = PaletteDraft(colors: [pc("#111111")])
        #expect(draft.remove(id: UUID()) == nil)
        #expect(draft.colors.count == 1)
    }

    @Test func setRoleNilClearsRole() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "Primary")])
        draft.setRole(nil, for: draft.colors[0].id)
        #expect(draft.colors[0].role == nil)
    }

    @Test func renameRoleRewritesEveryHolderCaseInsensitively() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "Brand"), pc("#222222", role: "brand"), pc("#333333", role: "Accent"), pc("#444444")])
        draft.renameRole("BRAND", to: "Hero")
        #expect(draft.colors.map(\.role) == ["Hero", "Hero", "Accent", nil])
    }

    @Test func clearRoleRemovesOnlyThatRole() {
        var draft = PaletteDraft(colors: [pc("#111111", role: "Brand"), pc("#222222", role: "Accent"), pc("#333333")])
        draft.clearRole("brand")
        #expect(draft.colors.map(\.role) == [nil, "Accent", nil])
    }
}
