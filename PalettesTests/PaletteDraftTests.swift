import Testing
import SwiftUI
@testable import Palettes

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
}
