# iPad and iPhone Duo (016)

> An audit of the app against Apple's Human Interface Guidelines for iPad and for iPhone Duo (announced 2026-09-09, on sale 2026-10-23), plus the emil-design-eng motion rules. Part 1 is done on `feature/ipad-duo-optimization`. Parts 2 and 3 are still to do.

## Sources

- HIG: [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (new page, 2026-09-09).
- Technology overview: [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).
- HIG: Designing for iPadOS, Multitasking, Windows, Sidebars (updated 2026-06-08), Split views, Toolbars, Keyboards, Drag and drop.
- API reference: `ReservedRegion`, `ArrangementView`, `ToolbarOverflowMenu`, `ToolbarItemVisibilityPriority`, `ToolbarVerticalCompressionBehavior`, `toolbarVerticalEdge`, `toolbarVerticalBehavior(_:)`, `axisBehavior(_:)`, `presentationPlacement(_:)`, `topBarPinnedTrailing`.

## What the guidance says, in short

**iPhone Duo**
- Two displays. The outer display is compact width and *wider and shorter* than other iPhones. The inner display is regular width. The app moves between them as the device opens and closes, so state and functionality must carry over.
- **Bars move to the side.** On the outer display, and on the inner display in landscape, the navigation bar, toolbar and tab bar sit vertically along one edge. Toolbar items need **both a title and a symbol**. An item with only a title, or with a custom view, cannot go in a vertical bar. Items overflow from bottom to top, and `visibilityPriority` changes that order. Use the **system overflow menu** (`ToolbarOverflowMenu`). Reserve the ellipsis symbol for overflow, and give other menus their own symbol.
- **Reserved regions.** These are the outer camera (always present), the inner camera (only while it's active) and the fold (only while the device is half open). Sheets, alerts, context menus and split views avoid them on their own. Custom layouts read them through `GeometryProxy.reservedRegions(kind:)`. Grids should **prefer an even number of columns** while folded. Avoid big layout jumps when the device folds.
- **Arrangement views** (`ArrangementView` with `.split` or `.overlay`) arrange a primary and a secondary view to suit the display shape and the fold. If a layout is already an HStack/VStack pair, it can become a split arrangement.
- **Build to resize.** Use size classes and the container's size. Don't use the screen size, `userInterfaceIdiom` or the orientation.

**iPad**
- Make good use of the large display and keep modal screens to a minimum. Support keyboard, pointer, Pencil and drag and drop.
- Multitasking and windowing are expected. Each window keeps its own context and restores it.
- iPadOS 26 has a menu bar. Put commands there with their shortcuts, rather than in hidden buttons.

## Audit findings

| # | Finding | Where | Severity |
|---|---------|-------|----------|
| A1 | `UIActivityViewController` was presented with no popover anchor. On iPad this throws an exception, so Share and Export as PNG from the library and detail context menus crashed. | `PaletteView`, `ColorsView`, `PaletteDetailView` (context menu) | **Crash** |
| A2 | Share sheets presented in `connectedScenes.first`. With two iPad windows, or as Duo moves between displays, that can be the wrong window. | all share paths, `ShareSheetPresenter` | High |
| A3 | The tab selection was app-wide (`AppData.activeTab`), so changing tabs in one iPad window changed every window. The tab was not restored either. | `PaletteTabView` | High |
| A4 | Keyboard shortcuts were hidden buttons and modifiers on the floating + buttons. ⌘N did nothing when the library was empty or another tab was showing. The shortcuts didn't appear in the iPadOS 26 menu bar. | `PaletteTabView`, `PaletteView`, `ColorsView` | Medium |
| A5 | Toolbar items had a symbol only (`Image` + `accessibilityLabel`) or text only (`"Select"`). On Duo, text-only items cannot go in vertical bars, and the overflow menu has no titles to show. | all toolbars, sheets' close buttons, select-mode bottom bar | Medium (Duo) |
| A6 | The library options (sort, filter, layout) menu used the ellipsis, which the HIG reserves for overflow. The detail screens used their own ellipsis menus instead of the system overflow menu. | `PaletteView`, `ColorsView`, detail views | Medium (Duo) |
| A7 | The generating stage was a fixed 300 pt orb stacked above text. It overflowed short displays: the Duo outer display, iPhone in landscape, short iPad windows. | `GenerateView.generatingOrb` | Medium |
| A8 | Nothing could be dragged out of the app, which the HIG lists as an iPad expectation. | library and detail cards | Medium |
| A9 | `.transition(.scale)` scaled from zero. | 7 sites in Generate and Search | Polish |

## Part 1 — done

- **A1, A2.** Every share now goes through `ShareSheetPresenter`. It presents in the foreground-active scene's key window and always sets a popover anchor that respects right-to-left layouts.
- **A3.** Added `SceneRouter`, which holds per-window state. The tab selection is `@SceneStorage`, so each window has its own tab and gets it back on restore. `AppData.activeTab` now only *requests* a tab switch (intents, onboarding, the cross-tab buttons), and windows follow those requests. First-visit intros read the window's tab through `\.selectedTab`. The Settings sheet moved to the tab view, so it opens from any tab.
- **A4.** Added `PalettesCommands` with **File:** New Palette ⌘N, New Color ⇧⌘N, New Window ⌥⌘N; **Settings…** ⌘,; and **View:** Palettes, Colors, Generate, Search on ⌘1–⌘4. Each command acts on the focused window through `focusedSceneValue`. The hidden buttons and per-button shortcuts are gone.
- **A5.** Every toolbar item is now a `Label`: Settings, Select (`checkmark.circle`), Select All/Deselect All (`checklist.checked`/`.unchecked`), Done Selecting, the share/export buttons, sheet close buttons, and the bottom select bar.
- **A6.** The library options menu uses `line.3.horizontal.decrease` with the title "View Options", and the onboarding tour copy now shows that symbol. Detail screens' "more" actions use the new `overflowMenu { }` shim (`Compatibility/ToolbarCompat.swift`): `ToolbarOverflowMenu` when built with Swift ≥ 6.4 (Xcode 27) and running iOS 27, otherwise the old ellipsis menu.
- **A7.** The generating stage is now a split arrangement built with `AnyLayout`: stacked when the stage is tall, side by side when it's wide. The orb's diameter scales with the stage, between 160 and 300 pt.
- **A8.** Palette cards drag out as text (the name, then one hex per line), and color cards drag out as their hex. Context menus still work.
- **A9.** Added `AnyTransition.pop`, which starts at 85% scale and fades in.

### Motion review (emil-design-eng)

| Before | After | Why |
| --- | --- | --- |
| `.transition(.scale.combined(with: .opacity))` | `.transition(.pop)`, i.e. `.scale(scale: 0.85)` with opacity | Nothing appears from nothing. A control that grows from 0 looks like it came from nowhere. |
| ⌘N/⇧⌘N on the floating buttons, ⌘1–⌘4 on hidden buttons | Menu-bar commands, with no animation of their own | Keyboard actions are used constantly, so they should be instant and discoverable, and they shouldn't depend on which view happens to be on screen. |
| Fixed 300 pt orb over the copy | Orb sized to the stage, stacked or side by side | Motion only works if the moving element and its context stay on screen. The orb's morph into the stage now ends inside the visible area. |
| Share popover anchored to an arbitrary corner, or not anchored at all | Anchored under the top trailing bar, mirrored for right-to-left | Popovers should come from where the action lives. With no anchor, iPad crashes. |

## Part 1b — fold layouts (done, from Device Hub screenshots)

`Compatibility/FoldCompat.swift` reads the active `.division` reserved region (iOS 27.1, behind `#if compiler(>=6.4)`. Note this means Xcode 27.0 can't build the branch; use 27.1+ or Xcode 26) and hands layouts a `Fold`.

- **Libraries** (`MorphingCardGrid.foldSpan`): with a vertical crease, the same number of columns sit on each side, centred in each half, with none on the crease. `LazyMorphingCardGrid` measures it itself; `PaletteView` passes it in.
- **Palette detail**: folded, the strip fills the side before the crease (the top, or the leading side in landscape) and the colors scroll on the other side. The title goes inline to give the strip room.
- **One rule for every split** (`FoldSplit`): the visual (orb, palette strip) takes the side before the crease, the top or the left, and text, buttons and controls take the side after it.
- **Onboarding**: with a horizontal crease, the orb is centred above it and the text and buttons sit below. With a vertical crease, the orb is on the left and the text and buttons are centred together on the right. Unfolded, the orb and text centre on the screen (the text is padded to match when the bars sit on one side).
- **Onboarding on the outer display**: the orb centres on the safe area (the same centre as the text) and is 15% smaller.
- **Generate**: folded, the orb is as large as its side allows (up to 460 pt), with size, mode, colors, vibe and Generate stacked on the other side. The generating stage splits the same way. Unfolded, the generating stage stays stacked and centred, and goes side by side only when the stage is under 520 pt tall. On a wide, short stage (the outer display in landscape), the size and mode menus sit in a column beside a strip three swatches wide, with the vibe field and Generate below.

## Part 2 — next, needs the iOS 27.1 SDK (Xcode 27.1, beta as of 2026-10)

These APIs are iOS 27.1 and appear only in the 27.1 SDK. Xcode 27.0 and CI (`macos-15`, latest stable) can't compile them. Gate them behind a custom `PALETTES_DUO_SDK` condition until 27.1 is the stable Xcode, then switch to `#available(iOS 27.1, *)` only.

1. ~~**Fold-aware grids.**~~ Done in part 1b, for the libraries. The palette detail's `LazyVGrid` scrolls in one half instead. Original note: in `MorphingCardGrid`, read `GeometryProxy.reservedRegions(kind: .division)`. While a division `isActive`, round the column count down to an even number. Also add the division's width to the gap between the middle columns, so no card sits on the fold. This applies to the Palettes and Colors libraries and the palette detail color grid (`LazyVGrid` → `MorphingCardGrid`).
2. **Floating + button vs. vertical bars.** The FAB sits at bottom trailing. When `@Environment(\.toolbarVerticalEdge) == .trailing`, the HIG puts frequent actions in the bar instead. Either move "New" into the toolbar there with `.visibilityPriority(.high)`, or align the FAB to the opposite edge.
3. **Arrangement views.** Replace the `AnyLayout` switch in `GenerateView.generatingOrb` with `ArrangementView { orb } secondary: { copy }` and `.arrangementViewStyle(.split)`, which also avoids the fold. Consider `.overlay` for the photo eyedropper (`PhotoColorPickerView`): photo as the secondary view, loupe and swatch as the primary. When half open, the photo takes one half and the controls the other.
4. **Bar compression.** Use `.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` on task screens (Generate result, New Palette, Color Edit), and the default `.prefersTabBar` on the libraries.
5. **Axis behavior.** In the Generate result screen, give the text-heavy items `.axisBehavior(.horizontalOnly)`.

## Part 3 — next, works with today's SDKs (or iOS 27.0 behind `#if compiler(>=6.4)`)

1. **Color editing in an inspector on regular width.** Today, tapping a color in a palette opens `ColorEditView` as a modal sheet. On iPad, and on the Duo inner display, use `.inspector(isPresented:)` (iOS 17) so the palette stays visible while editing. It becomes a sheet automatically in compact width. Save/Cancel semantics need care, because the sheet currently binds straight into `AppData`.
2. **Restore navigation per window.** Encode `PaletteView`/`ColorsView` `NavigationPath`s (palette and color ids) in `@SceneStorage`, so an open palette survives a window restore and the Duo display switch.
3. **Open in New Window.** Add a context-menu action using `openWindow(value: palette.id)` with a `WindowGroup(for: UUID.self)` that shows `PaletteDetailView`.
4. **Drop in.** Accept dropped hex text and images on the libraries (`.dropDestination(for: String.self)`, and for images run `ImageColorExtractor` → New Palette).
5. **Toolbar priorities (iOS 27.0).** Behind `#if compiler(>=6.4)` and `#available(iOS 27.0, *)`: give Settings `.visibilityPriority(.low)`, and put sheet confirmations (Create, Save) in `.topBarPinnedTrailing`. Use view-level shims, not `if #available … else` inside `ToolbarContentBuilder` (its availability overloads vary by OS).
6. **Sheet placement on the Duo inner display (iOS 27.0).** Give the export sheet and role picker `.presentationPlacement(.trailing)` so the palette stays visible.
7. **Card press feedback.** Cards use `onTapGesture` and contain inner buttons, so they have no touch-down feedback. A `ButtonStyle` at 0.97 scale (160 ms ease-out) needs the inner View/Copy buttons moved out of the card label first.
8. **⌘F** to focus search, and **⌘⌫** to delete the selection in select mode.

## Verification (Xcode machine)

Linux had no Swift toolchain, so this change was only syntax-checked (tree-sitter, all touched files parse). Still needed:

1. `xcodebuild build` on Xcode 26.x (CI) **and** Xcode 27 (exercises the `#if compiler(>=6.4)` branch in `ToolbarCompat.swift`).
2. iPad: open two windows, switch tabs in one (the other must not follow), close and reopen (the tab is restored); try ⌘N with an empty library, ⇧⌘N from the Palettes tab, ⌘, from Search; check the iPadOS 26 menu bar entries; use Share from a library card's context menu (it used to crash).
3. iPhone Duo in Device Hub (Xcode 27.1): outer display, open, half open, rotated. Check the toolbar items in vertical bars, the overflow menu titles, the generating stage on the outer display, and dragging a palette into Notes.
4. iOS 17 simulator: the legacy tab bar, Settings from the gear button, and the onboarding replay from Settings (the Settings sheet moved to the tab view, so re-check the replay timing).
