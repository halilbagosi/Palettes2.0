//
//  EntityIndexerTests.swift
//  PalettesTests
//

import XCTest
import SwiftUI
@testable import Palettes

@available(iOS 26.0, *)
@MainActor
final class EntityIndexerTests: XCTestCase {

    private var applied: [Int] = []
    private var originalApplier: (([PaletteEntity], [ColorEntity]) async -> Void)!

    override func setUp() async throws {
        originalApplier = EntityIndexer.applier
        applied = []
        EntityIndexer.applier = { [weak self] palettes, _ in
            try? await Task.sleep(for: .milliseconds(100))
            await MainActor.run { self?.applied.append(palettes.count) }
        }
    }

    override func tearDown() async throws {
        await waitUntilIdle()
        XCTAssertTrue(EntityIndexer.isIdle, "indexer worker still running at tearDown")
        EntityIndexer.applier = originalApplier
    }

    private func palettes(_ n: Int) -> [PaletteEntity] {
        (0..<n).map { PaletteEntity(id: UUID(), name: "P\($0)", hexCodes: ["#000000"]) }
    }

    private func waitUntilIdle() async {
        for _ in 0..<100 where !EntityIndexer.isIdle {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Rapid snapshots never overlap, intermediate ones are coalesced away,
    /// and the newest one is always applied last.
    func testRapidReindexesCoalesceAndApplyNewestLast() async {
        EntityIndexer.reindex(palettes: palettes(1), colors: [])
        // Let job 1 start (its applier sleeps 100 ms) before queuing more.
        try? await Task.sleep(for: .milliseconds(30))
        EntityIndexer.reindex(palettes: palettes(2), colors: [])
        EntityIndexer.reindex(palettes: palettes(3), colors: [])
        await waitUntilIdle()
        XCTAssertEqual(applied, [1, 3])
    }

    /// A delete-everything request queued behind an in-flight job wins: no
    /// older snapshot can re-add entities after it.
    func testRemoveAllAfterPendingSnapshotWins() async {
        EntityIndexer.reindex(palettes: palettes(5), colors: [])
        // The stub applier sleeps 100 ms, so job 1 is in flight after this.
        try? await Task.sleep(for: .milliseconds(30))
        EntityIndexer.reindex(palettes: palettes(4), colors: [])
        EntityIndexer.removeAll()
        await waitUntilIdle()
        XCTAssertEqual(applied, [5, 0])
    }
}
