import Testing
@testable import Palettes

struct OptionsTourGateTests {
    @Test func presentsOnlyWhenArmedEmptyAndOnPalettesTab() {
        #expect(OptionsTourGate.shouldPresent(flag: true, pathIsEmpty: true, selectedTabIsPalettes: true))
        #expect(!OptionsTourGate.shouldPresent(flag: false, pathIsEmpty: true, selectedTabIsPalettes: true))
        #expect(!OptionsTourGate.shouldPresent(flag: true, pathIsEmpty: false, selectedTabIsPalettes: true))
        #expect(!OptionsTourGate.shouldPresent(flag: true, pathIsEmpty: true, selectedTabIsPalettes: false))
    }
}
