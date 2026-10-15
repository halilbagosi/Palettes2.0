//
//  GenerationPacingTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

final class GenerationPacingTests: XCTestCase {

    func testOnlyIndexZeroRevealsWithoutWaiting() {
        // Nothing locked: index 0 is the first generated color and lands at once.
        XCTAssertFalse(GenerationPacing.waitsBeforeRevealing(colorAt: 0))
        // One locked color on screen: the first generated color (index 1) waits.
        XCTAssertTrue(GenerationPacing.waitsBeforeRevealing(colorAt: 1))
        XCTAssertTrue(GenerationPacing.waitsBeforeRevealing(colorAt: 5))
    }

    func testFullRevealFitsWellInsideOnboardingBudget() {
        // Four colors, one locked: three waits. Must stay under ~1.5s.
        XCTAssertLessThan(GenerationPacing.colorInterval * 3, .milliseconds(1500))
        XCTAssertLessThan(GenerationPacing.namingGrace, GenerationPacing.colorInterval * 2)
    }

    func testRevealStepsWithAnchorShown() {
        let steps = OnboardingPaletteMaker.revealSteps(total: 4, shown: 1)
        XCTAssertEqual(steps.map(\.count), [2, 3, 4])
        XCTAssertTrue(steps.allSatisfy(\.waitsFirst))
    }

    func testRevealStepsFromPhotoShowFirstImmediately() {
        let steps = OnboardingPaletteMaker.revealSteps(total: 4, shown: 0)
        XCTAssertEqual(steps.map(\.count), [1, 2, 3, 4])
        XCTAssertEqual(steps.map(\.waitsFirst), [false, true, true, true])
    }

    func testRevealStepsEmptyWhenAllShown() {
        XCTAssertTrue(OnboardingPaletteMaker.revealSteps(total: 1, shown: 1).isEmpty)
    }

    func testNamingRaceReturnsFastResult() async {
        let task = Task { 42 }
        let value = await NamingRace.firstResult(of: task, within: .seconds(2))
        XCTAssertEqual(value, 42)
    }

    func testNamingRaceTimesOutOnSlowTask() async {
        let task = Task { () -> Int in
            try? await Task.sleep(for: .seconds(3))
            return 1
        }
        let start = ContinuousClock.now
        let value = await NamingRace.firstResult(of: task, within: .milliseconds(100))
        task.cancel()
        XCTAssertNil(value)
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(1))
    }
}

// MARK: - Late naming

private func palette(_ name: String, generated: Bool = false, id: UUID = UUID()) -> PaletteViewModel {
    PaletteViewModel(id: id, name: name, colors: [.red, .blue], hexCodes: ["#FF0000", "#0000FF"],
                     colorNames: ["A", "B"], isGenerated: generated)
}

@MainActor
final class LateNamingTests: XCTestCase {

    private func flow() -> OnboardingInterimFlow {
        OnboardingInterimFlow(model: OnboardingModel())
    }

    private func made(_ name: String) -> OnboardingPaletteMaker.Made {
        .init(palette: palette(name, generated: true), usedAI: true, anchorHex: "#FF0000")
    }

    private func shownName(_ flow: OnboardingInterimFlow) -> String? {
        if case .ready(let made) = flow.genState { return made.palette.name }
        return nil
    }

    func testSwapKeepsIdAndGeneratedTag() {
        let shown = palette("Fallback", generated: true)
        let late = palette("Harbor Dusk", generated: false)
        let result = OnboardingInterimFlow.swapped(shown, with: late)
        XCTAssertEqual(result.name, "Harbor Dusk")
        XCTAssertEqual(result.id, shown.id)
        XCTAssertTrue(result.isGenerated)
    }

    func testLateNameAfterReadySwapsTitle() {
        let flow = flow()
        flow.markReady(made("Fallback"))
        flow.applyLateNaming(palette("Harbor Dusk"))
        XCTAssertEqual(shownName(flow), "Harbor Dusk")
    }

    func testLateNameBeforeReadyIsStashedThenApplied() {
        let flow = flow()
        flow.applyLateNaming(palette("Harbor Dusk"))
        XCTAssertNil(shownName(flow))
        XCTAssertNotNil(flow.pendingLatePalette)
        flow.markReady(made("Fallback"))
        XCTAssertEqual(shownName(flow), "Harbor Dusk")
        XCTAssertNil(flow.pendingLatePalette)
    }

    func testLateNameIgnoredOnceSaving() {
        let flow = flow()
        flow.markReady(made("Fallback"))
        flow.isSaving = true
        flow.applyLateNaming(palette("Harbor Dusk"))
        XCTAssertEqual(shownName(flow), "Fallback")
    }

    func testStashedLateNameIgnoredIfSavingBeforeReady() {
        let flow = flow()
        flow.applyLateNaming(palette("Harbor Dusk"))
        flow.isSaving = true
        flow.markReady(made("Fallback"))
        XCTAssertEqual(shownName(flow), "Fallback")
    }

    func testStaleRunLateNameIsDropped() {
        let flow = flow()
        flow.markReady(made("Fallback"))
        flow.receiveLate(palette("Old Run"), runID: flow.runID + 1)
        XCTAssertEqual(shownName(flow), "Fallback")
        flow.receiveLate(palette("Current"), runID: flow.runID)
        XCTAssertEqual(shownName(flow), "Current")
    }

    func testStopClearsStashedName() {
        let flow = flow()
        flow.applyLateNaming(palette("Harbor Dusk"))
        flow.stop()
        XCTAssertNil(flow.pendingLatePalette)
    }

    // The generator's late path.

    @available(iOS 26.0, *)
    func testLateNamingTaskDeliversAssembledPalette() async {
        let naming = Task { "Harbor Dusk" }
        var delivered: [String] = []
        let task = PaletteGenerator.lateNamingTask(
            awaiting: naming, isUseful: { !$0.isEmpty },
            assemble: { palette($0) }, deliver: { delivered.append($0.name) })
        await task.value
        XCTAssertEqual(delivered, ["Harbor Dusk"])
    }

    @available(iOS 26.0, *)
    func testLateNamingTaskSkipsUselessResult() async {
        let naming = Task { "" }
        var delivered = 0
        let task = PaletteGenerator.lateNamingTask(
            awaiting: naming, isUseful: { !$0.isEmpty },
            assemble: { palette($0) }, deliver: { _ in delivered += 1 })
        await task.value
        XCTAssertEqual(delivered, 0)
    }

    @available(iOS 26.0, *)
    func testCancellingLateNamingTaskCancelsModelCallAndNeverDelivers() async {
        let modelCancelled = expectation(description: "model call cancelled")
        let naming = Task { () -> String in
            while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(10)) }
            modelCancelled.fulfill()
            return "Late"
        }
        var delivered = 0
        let task = PaletteGenerator.lateNamingTask(
            awaiting: naming, isUseful: { _ in true },
            assemble: { palette($0) }, deliver: { _ in delivered += 1 })
        task.cancel()
        await fulfillment(of: [modelCancelled], timeout: 2)
        await task.value
        XCTAssertEqual(delivered, 0)
    }

    // The grace race.

    func testNamingRaceAtTheTimeoutResumesOnce() async {
        // Finish right around the timeout, many times: a double resume of
        // the continuation would trap.
        for offset in [-2, -1, 0, 1, 2] {
            for _ in 0..<20 {
                let task = Task { () -> Int in
                    try? await Task.sleep(for: .milliseconds(20 + offset))
                    return 7
                }
                let value = await NamingRace.firstResult(of: task, within: .milliseconds(20))
                XCTAssertTrue(value == 7 || value == nil)
            }
        }
    }
}

// MARK: - Generate tab late naming

final class GeneratedResultLateNamingTests: XCTestCase {

    private func color(_ hex: String, _ name: String) -> PaletteColor {
        PaletteColor(color: Color(hex: hex) ?? .gray, hex: hex, name: name)
    }

    private let shown = PaletteViewModel(name: "Fallback", colors: [.red, .blue, .green],
                                         hexCodes: ["#FF0000", "#0000FF", "#00FF00"],
                                         colorNames: ["Red", "Blue", "Green"])
    private let late = PaletteViewModel(name: "Harbor Dusk", colors: [.red, .blue, .green],
                                        hexCodes: ["#FF0000", "#0000FF", "#00FF00"],
                                        colorNames: ["Ember", "Cobalt", "Fern"])

    func testUntouchedResultTakesEveryLateName() {
        let merged = GeneratedResultNaming.merge(
            name: "Fallback", colors: shown.paletteColors, shown: shown, late: late)
        XCTAssertEqual(merged.name, "Harbor Dusk")
        XCTAssertEqual(merged.colors.map(\.name), ["Ember", "Cobalt", "Fern"])
        // Identity is kept so the result list doesn't rebuild its rows.
        XCTAssertEqual(merged.colors.map(\.id), shown.paletteColors.map(\.id))
    }

    func testUserEditsSurvive() {
        var colors = shown.paletteColors
        colors[1].name = "My Blue"          // renamed
        colors.remove(at: 2)                // removed
        colors.append(color("#123456", "Added"))  // added by the user
        let merged = GeneratedResultNaming.merge(
            name: "My Title", colors: colors, shown: shown, late: late)
        XCTAssertEqual(merged.name, "My Title")
        XCTAssertEqual(merged.colors.map(\.name), ["Ember", "My Blue", "Added"])
    }

    func testRecoloredSwatchKeepsItsName() {
        var colors = shown.paletteColors
        colors[0].hex = "#EE0000"
        let merged = GeneratedResultNaming.merge(
            name: "Fallback", colors: colors, shown: shown, late: late)
        XCTAssertEqual(merged.colors[0].name, "Red")
    }
}
