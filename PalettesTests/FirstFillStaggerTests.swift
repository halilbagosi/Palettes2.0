import Testing
import Foundation
@testable import Palettes

@MainActor
struct FirstFillStaggerTests {
    private func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

    @Test func staggersAnEmptyPaletteReceivingSeveralColors() {
        let added = ids(4)
        let plan = FirstFillStagger.plan(existingCount: 0, added: added)
        #expect(plan.count == 4)
        for (i, id) in added.enumerated() { #expect(plan[id] == i) }
    }

    @Test func doesNotStaggerASingleColor() {
        #expect(FirstFillStagger.plan(existingCount: 0, added: ids(1)).isEmpty)
        #expect(FirstFillStagger.plan(existingCount: 0, added: []).isEmpty)
    }

    @Test func doesNotStaggerAPaletteThatAlreadyHasColors() {
        #expect(FirstFillStagger.plan(existingCount: 1, added: ids(5)).isEmpty)
    }

    @Test func delayIsFortyMillisecondsPerIndex() {
        #expect(FirstFillStagger.delay(forIndex: 0) == 0)
        #expect(abs(FirstFillStagger.delay(forIndex: 5) - 0.2) < 1e-9)
    }

    @Test func totalDurationCoversTheLastItem() {
        #expect(abs(FirstFillStagger.totalDuration(count: 6) - (0.2 + 0.35)) < 1e-9)
        #expect(FirstFillStagger.totalDuration(count: 0) == FirstFillStagger.duration)
    }
}
