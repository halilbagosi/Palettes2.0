import SwiftUI
import Combine
import SwiftData
import CoreData
import UIKit

@MainActor
class AppData: ObservableObject {
    @Published var activeTab: TabValue = .palettes

    /// Color to pre-select when the Generate tab is opened from a color detail view.
    @Published var pendingGenerateColorID: UUID?

    @Published var colors: [ColorViewModel] = []
    @Published var palettes: [PaletteViewModel] = []

    /// Single app-wide instance shared by the UI and App Intents so both see
    /// (and persist through) the same in-memory library.
    static let shared = AppData()

    /// Palette id an Open intent asked to show; PaletteView consumes it.
    @Published var pendingOpenPaletteID: UUID?

    private var container: ModelContainer?
    private var cancellables: Set<AnyCancellable> = []

    /// True while the published arrays are being replaced from the store, so
    /// the debounced persistence sinks don't write back what was just read.
    private var isReloading = false

    /// Pending task that clears `isReloading`; cancelled and replaced on each
    /// reload so the flag clears 600 ms after the most recent one.
    private var reloadResetTask: Task<Void, Never>?

    /// True when `colors`/`palettes` have local edits that haven't been
    /// successfully persisted yet (e.g. because a reload was in flight, or
    /// the last save failed). Used to flush before reloads and retry after.
    private var isDirtyColors = false
    private var isDirtyPalettes = false

    /// ids the store held as of the most recent load/persist, used to tell
    /// "user deleted this" apart from "this arrived from CloudKit after our
    /// snapshot was taken" when diffing on persist.
    private var lastPersistedColorIDs: Set<UUID> = []
    private var lastPersistedPaletteIDs: Set<UUID> = []

    init(inMemory: Bool = false) {
        if inMemory {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try? ModelContainer(for: StoredColor.self, StoredPalette.self, configurations: config)
        } else {
            // Prefer iCloud-synced storage; fall back to a purely local store
            // (e.g. entitlement missing or iCloud unavailable), then to a
            // session-only experience rather than crashing.
            let cloud = ModelConfiguration(cloudKitDatabase: .automatic)
            if let cloudContainer = try? ModelContainer(for: StoredColor.self, StoredPalette.self, configurations: cloud) {
                container = cloudContainer
            } else {
                let local = ModelConfiguration(cloudKitDatabase: .none)
                container = try? ModelContainer(for: StoredColor.self, StoredPalette.self, configurations: local)
            }
        }

        load()

        // Persist whenever the arrays change, debounced so bursts of edits
        // (e.g. saving a generated palette) write once.
        $colors
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] updated in
                guard let self, !self.isReloading else { return }
                Task { @MainActor in self.persistColors(updated) }
            }
            .store(in: &cancellables)

        $palettes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] updated in
                guard let self, !self.isReloading else { return }
                Task { @MainActor in self.persistPalettes(updated) }
            }
            .store(in: &cancellables)

        // Keep Spotlight's copy of the library current so Siri can find it.
        // (No dropFirst() — the initial load should also be indexed.)
        $palettes.combineLatest($colors)
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { palettes, colors in
                // `PaletteEntity.init`/`ColorEntity.init` are @MainActor; the
                // sink closure itself isn't isolated, so hop explicitly
                // (matching the persistence sinks above) rather than relying
                // on RunLoop.main scheduling to satisfy the compiler.
                Task { @MainActor in
                    if #available(iOS 26.0, *) {
                        EntityIndexer.reindex(
                            palettes: palettes.map(PaletteEntity.init),
                            colors: colors.map(ColorEntity.init)
                        )
                    }
                }
            }
            .store(in: &cancellables)

        // Mark edits dirty immediately (not debounced) so a reload that
        // lands mid-debounce knows there's unpersisted work to flush/retry.
        $colors
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isReloading else { return }
                self.isDirtyColors = true
            }
            .store(in: &cancellables)

        $palettes
            .dropFirst()
            .sink { [weak self] _ in
                guard let self, !self.isReloading else { return }
                self.isDirtyPalettes = true
            }
            .store(in: &cancellables)

        // Reload when CloudKit finishes importing changes from another
        // device, and on foregrounding as a safety net.
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .compactMap { note in
                note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event
            }
            .filter { $0.type == .import && $0.endDate != nil }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFromStore() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadFromStore() }
            .store(in: &cancellables)
    }

    // MARK: - Load

    /// Refetches the store and replaces the published arrays without
    /// triggering a write-back. The flag outlives the sinks' 300 ms debounce
    /// and clears 600 ms after the most recent reload.
    private func reloadFromStore() {
        guard container != nil else { return }
        // Flush any pending local edits before we replace the in-memory
        // arrays, so a reload can't clobber work that hasn't hit the store.
        if isDirtyColors { persistColors(colors) }
        if isDirtyPalettes { persistPalettes(palettes) }
        isReloading = true
        load()
        reloadResetTask?.cancel()
        reloadResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self.isReloading = false
            // Retry any edit whose debounced persist was guarded out while
            // isReloading was true.
            if self.isDirtyColors { self.persistColors(self.colors) }
            if self.isDirtyPalettes { self.persistPalettes(self.palettes) }
        }
    }

    private func load() {
        guard let context = container?.mainContext else {
            colors = Self.sampleColors
            palettes = Self.samplePalettes
            return
        }

        let storedColors = (try? context.fetch(
            FetchDescriptor<StoredColor>(sortBy: [SortDescriptor(\.sortIndex)])
        )) ?? []
        let storedPalettes = (try? context.fetch(
            FetchDescriptor<StoredPalette>(sortBy: [SortDescriptor(\.sortIndex)])
        )) ?? []

        lastPersistedColorIDs = Set(storedColors.map(\.id))
        lastPersistedPaletteIDs = Set(storedPalettes.map(\.id))

        let didSeed = UserDefaults.standard.bool(forKey: "didSeedSampleData")
        if storedColors.isEmpty && storedPalettes.isEmpty && !didSeed {
            // First launch with an empty store: seed the sample library. On a
            // new device whose iCloud data hasn't downloaded yet this may run
            // once; the flag prevents repeats and synced records merge in on
            // the next import event.
            colors = Self.sampleColors
            palettes = Self.samplePalettes
            UserDefaults.standard.set(true, forKey: "didSeedSampleData")
            persistColors(colors)
            persistPalettes(palettes)
        } else {
            var seenColorIDs = Set<UUID>()
            let uniqueColors = storedColors.filter { seenColorIDs.insert($0.id).inserted }
            var seenPaletteIDs = Set<UUID>()
            let uniquePalettes = storedPalettes.filter { seenPaletteIDs.insert($0.id).inserted }

            colors = uniqueColors.map {
                ColorViewModel(
                    id: $0.id,
                    name: $0.name,
                    color: Color(hex: $0.hex) ?? .gray,
                    HEX: $0.hex,
                    usedInPalette: $0.usedInPalette,
                    isFavorite: $0.isFavorite
                )
            }
            palettes = uniquePalettes.map { stored in
                PaletteViewModel(
                    id: stored.id,
                    name: stored.name,
                    colors: stored.hexCodes.map { Color(hex: $0) ?? .gray },
                    hexCodes: stored.hexCodes,
                    colorNames: stored.colorNames,
                    isFavorite: stored.isFavorite
                )
            }
        }
    }

    // MARK: - Persist

    /// Upserts by id instead of rewriting the table so CloudKit only syncs
    /// the records that actually changed. Duplicate-id records (which CloudKit
    /// can create when two devices insert before first sync) are deleted on
    /// the next save.
    private func persistColors(_ list: [ColorViewModel]) {
        guard let context = container?.mainContext else { return }
        let existing = (try? context.fetch(FetchDescriptor<StoredColor>())) ?? []
        var byID: [UUID: StoredColor] = [:]
        var duplicates: [StoredColor] = []
        for item in existing {
            if byID[item.id] != nil { duplicates.append(item) } else { byID[item.id] = item }
        }

        for (index, color) in list.enumerated() {
            if let stored = byID.removeValue(forKey: color.id) {
                if stored.name != color.name { stored.name = color.name }
                if stored.hex != color.HEX { stored.hex = color.HEX }
                if stored.usedInPalette != color.usedInPalette { stored.usedInPalette = color.usedInPalette }
                if stored.isFavorite != color.isFavorite { stored.isFavorite = color.isFavorite }
                if stored.sortIndex != index { stored.sortIndex = index }
            } else {
                context.insert(StoredColor(
                    id: color.id,
                    name: color.name,
                    hex: color.HEX,
                    usedInPalette: color.usedInPalette,
                    isFavorite: color.isFavorite,
                    sortIndex: index
                ))
            }
        }
        for duplicate in duplicates { context.delete(duplicate) }

        var sawFreshRemote = false
        var keptFreshRemoteIDs: Set<UUID> = []
        for (id, orphan) in byID {
            if lastPersistedColorIDs.contains(id) {
                context.delete(orphan)          // user-removed: we knew this record
            } else {
                sawFreshRemote = true           // arrived from CloudKit after our snapshot: keep
                keptFreshRemoteIDs.insert(id)
            }
        }

        guard context.hasChanges else {
            isDirtyColors = false
            return
        }
        do {
            try context.save()
            isDirtyColors = false
            lastPersistedColorIDs = Set(list.map(\.id)).union(keptFreshRemoteIDs)
            if sawFreshRemote {
                reloadFromStore()
            }
        } catch {
            ToastManager.shared.show("Couldn't save your changes.", icon: "exclamationmark.triangle.fill")
            // dirty flag stays set so the next edit or reload retries the save
        }
    }

    private func persistPalettes(_ list: [PaletteViewModel]) {
        guard let context = container?.mainContext else { return }
        let existing = (try? context.fetch(FetchDescriptor<StoredPalette>())) ?? []
        var byID: [UUID: StoredPalette] = [:]
        var duplicates: [StoredPalette] = []
        for item in existing {
            if byID[item.id] != nil { duplicates.append(item) } else { byID[item.id] = item }
        }

        for (index, palette) in list.enumerated() {
            if let stored = byID.removeValue(forKey: palette.id) {
                if stored.name != palette.name { stored.name = palette.name }
                if stored.hexCodes != palette.hexCodes { stored.hexCodes = palette.hexCodes }
                if stored.colorNames != palette.colorNames { stored.colorNames = palette.colorNames }
                if stored.isFavorite != palette.isFavorite { stored.isFavorite = palette.isFavorite }
                if stored.sortIndex != index { stored.sortIndex = index }
            } else {
                context.insert(StoredPalette(
                    id: palette.id,
                    name: palette.name,
                    hexCodes: palette.hexCodes,
                    colorNames: palette.colorNames,
                    isFavorite: palette.isFavorite,
                    sortIndex: index
                ))
            }
        }
        for duplicate in duplicates { context.delete(duplicate) }

        var sawFreshRemote = false
        var keptFreshRemoteIDs: Set<UUID> = []
        for (id, orphan) in byID {
            if lastPersistedPaletteIDs.contains(id) {
                context.delete(orphan)          // user-removed: we knew this record
            } else {
                sawFreshRemote = true           // arrived from CloudKit after our snapshot: keep
                keptFreshRemoteIDs.insert(id)
            }
        }

        guard context.hasChanges else {
            isDirtyPalettes = false
            return
        }
        do {
            try context.save()
            isDirtyPalettes = false
            lastPersistedPaletteIDs = Set(list.map(\.id)).union(keptFreshRemoteIDs)
            if sawFreshRemote {
                reloadFromStore()
            }
        } catch {
            ToastManager.shared.show("Couldn't save your changes.", icon: "exclamationmark.triangle.fill")
            // dirty flag stays set so the next edit or reload retries the save
        }
    }

    #if DEBUG
    /// Test-only seam for directly manipulating the underlying store to
    /// simulate out-of-band changes (e.g. a CloudKit import arriving).
    internal var testContext: ModelContext? { container?.mainContext }
    #endif

    // MARK: - Intent API

    /// Appends a palette; the debounced sink persists it.
    @discardableResult
    func addPalette(name: String, paletteColors: [PaletteColor]) -> PaletteViewModel {
        let palette = PaletteViewModel(name: name, paletteColors: paletteColors)
        palettes.append(palette)
        return palette
    }

    /// Appends a standalone color; the debounced sink persists it.
    @discardableResult
    func addColor(name: String, hex: String) -> ColorViewModel {
        let color = ColorViewModel(
            name: name,
            color: Color(hex: hex) ?? .gray,
            HEX: hex,
            usedInPalette: false
        )
        colors.append(color)
        return color
    }

    // MARK: - Favorites

    /// Stars every id in `ids`; if they are all already starred, clears them
    /// instead (matching the toggle behaviour of Mail's flag button).
    func setColorsFavorite(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let allFavorite = colors.filter { ids.contains($0.id) }.allSatisfy(\.isFavorite)
        for i in colors.indices where ids.contains(colors[i].id) {
            colors[i].isFavorite = !allFavorite
        }
    }

    func setPalettesFavorite(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let allFavorite = palettes.filter { ids.contains($0.id) }.allSatisfy(\.isFavorite)
        for i in palettes.indices where ids.contains(palettes[i].id) {
            palettes[i].isFavorite = !allFavorite
        }
    }

    // MARK: - Sample Data (first launch only)

    private static let sampleColors: [ColorViewModel] = [
        ColorViewModel(name: "Maroon", color: Color(hex: "800000")!, HEX: "#800000", usedInPalette: true),
        ColorViewModel(name: "Electric Blue", color: Color(hex: "007AFF")!, HEX: "#007AFF", usedInPalette: false),
        ColorViewModel(name: "Sunset Orange", color: Color(hex: "FF5D00")!, HEX: "#FF5D00", usedInPalette: true),
        ColorViewModel(name: "Neon Lime", color: Color(hex: "CCFF00")!, HEX: "#CCFF00", usedInPalette: true),
        ColorViewModel(name: "Hot Pink", color: Color(hex: "FF0080")!, HEX: "#FF0080", usedInPalette: true),
        ColorViewModel(name: "Pastel Mint", color: Color(hex: "99FA99")!, HEX: "#99FA99", usedInPalette: true),
        ColorViewModel(name: "Soft Lavender", color: Color(hex: "E6E6FA")!, HEX: "#E6E6FA", usedInPalette: true),
        ColorViewModel(name: "Peach", color: Color(hex: "FFCC99")!, HEX: "#FFCC99", usedInPalette: false),
        ColorViewModel(name: "Midnight", color: Color(hex: "1A1A70")!, HEX: "#1A1A70", usedInPalette: true),
        ColorViewModel(name: "Charcoal", color: Color(hex: "333333")!, HEX: "#333333", usedInPalette: true),
        ColorViewModel(name: "Forest Green", color: Color(hex: "1B4D1B")!, HEX: "#1B4D1B", usedInPalette: true),
    ]

    private static let samplePalettes: [PaletteViewModel] = [
        PaletteViewModel(
            name: "Midnight Ocean",
            colors: [
                Color(hex: "1A1A70")!,
                Color(hex: "007AFF")!,
                Color(hex: "99FA99")!,
                Color(hex: "E6E6FA")!
            ],
            hexCodes: ["#1A1A70", "#007AFF", "#99FA99", "#E6E6FA"],
            colorNames: ["Midnight", "Electric Blue", "Pastel Mint", "Soft Lavender"]
        ),
        PaletteViewModel(
            name: "Sunset Glow",
            colors: [
                Color(hex: "FF5D00")!,
                Color(hex: "FF0080")!,
                Color(hex: "CCFF00")!,
                Color(hex: "FFCC99")!
            ],
            hexCodes: ["#FF5D00", "#FF0080", "#CCFF00", "#FFCC99"],
            colorNames: ["Sunset Orange", "Hot Pink", "Neon Lime", "Peach"]
        ),
        PaletteViewModel(
            name: "Forest Floor",
            colors: [
                Color(hex: "1B4D1B")!,
                Color(hex: "99FA99")!,
                Color(hex: "333333")!
            ],
            hexCodes: ["#1B4D1B", "#99FA99", "#333333"],
            colorNames: ["Forest Green", "Pastel Mint", "Charcoal"]
        ),
        PaletteViewModel(
            name: "Warm Dusk",
            colors: [
                Color(hex: "D4456A")!,
                Color(hex: "FF8C42")!,
                Color(hex: "FBD87F")!,
                Color(hex: "2E1A47")!
            ],
            hexCodes: ["#D4456A", "#FF8C42", "#FBD87F", "#2E1A47"],
            colorNames: ["Crimson", "Dark Orange", "Khaki", "Indigo"]
        ),
        PaletteViewModel(
            name: "Bold Contrast",
            colors: [
                Color(hex: "800000")!,
                Color(hex: "333333")!,
                Color(hex: "E6E6FA")!,
                Color(hex: "CCFF00")!
            ],
            hexCodes: ["#800000", "#333333", "#E6E6FA", "#CCFF00"],
            colorNames: ["Maroon", "Charcoal", "Soft Lavender", "Neon Lime"]
        ),
    ]
}
