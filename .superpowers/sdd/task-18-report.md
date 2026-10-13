# Task 18 report
- LibrarySearch (Utilities) shared by SearchView, SearchMatching, intents, entity queries. Colours: name, hex +/- #, hue words (blue/blues, warm, cool). Palettes: name, role tags, colour names/hexes.
- FindPalettesIntent / new FindColorsIntent (value + "Found N ..." dialog + snippets); new SearchLibraryIntent -> AppData.pendingSearchTerm + activeTab=.search, consumed by SearchView.
- App Shortcuts now 8 (<10): added Find Palettes, Find Colors, Search Library, Create Palette.
- EntityIndexer unchanged (already indexes both); updateAppShortcutParameters wired in Task 17.
- Tests: LibrarySearchTests (pure + intent-level, AppData.shared seeded). Full suite: 72 tests in 15 suites passed.
- Not driven: device verification owed (Shortcuts lists all 8; Find Colors "blue" chained; Siri "Search my palettes in Palettes").
