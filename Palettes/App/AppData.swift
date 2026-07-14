import SwiftUI
import Combine
import SwiftData

@MainActor
class AppData: ObservableObject {
    @Published var activeTab: TabValue = .palettes

    /// Color to pre-select when the Generate tab is opened from a color detail view.
    @Published var pendingGenerateColorID: UUID?

    @Published var colors: [ColorViewModel] = []
    @Published var palettes: [PaletteViewModel] = []

    private var container: ModelContainer?
    private var cancellables: Set<AnyCancellable> = []

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
                Task { @MainActor in self?.persistColors(updated) }
            }
            .store(in: &cancellables)

        $palettes
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] updated in
                Task { @MainActor in self?.persistPalettes(updated) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Load

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

        let didSeed = UserDefaults.standard.bool(forKey: "didSeedSampleData")
        if storedColors.isEmpty && storedPalettes.isEmpty && !didSeed {
            // First launch: start from the sample library.
            colors = Self.sampleColors
            palettes = Self.samplePalettes
            UserDefaults.standard.set(true, forKey: "didSeedSampleData")
            persistColors(colors)
            persistPalettes(palettes)
        } else {
            colors = storedColors.map {
                ColorViewModel(
                    id: $0.id,
                    name: $0.name,
                    color: Color(hex: $0.hex) ?? .gray,
                    HEX: $0.hex,
                    usedInPalette: $0.usedInPalette,
                    isFavorite: $0.isFavorite
                )
            }
            palettes = storedPalettes.map { stored in
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
    /// the records that actually changed.
    private func persistColors(_ list: [ColorViewModel]) {
        guard let context = container?.mainContext else { return }
        let existing = (try? context.fetch(FetchDescriptor<StoredColor>())) ?? []
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

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
        for orphan in byID.values { context.delete(orphan) }
        if context.hasChanges { try? context.save() }
    }

    private func persistPalettes(_ list: [PaletteViewModel]) {
        guard let context = container?.mainContext else { return }
        let existing = (try? context.fetch(FetchDescriptor<StoredPalette>())) ?? []
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

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
        for orphan in byID.values { context.delete(orphan) }
        if context.hasChanges { try? context.save() }
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
