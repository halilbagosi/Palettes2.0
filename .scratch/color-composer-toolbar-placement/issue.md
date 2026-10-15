# ColorComposer toolbar: Save placement

Status: needs-triage

Apple's Duo / iOS 27 sheet guidance puts the confirm action (Save) in `topBarPinnedTrailing`, so it stays pinned while the sheet scrolls or resizes.

Placement is not set by `SheetConfirmButton` / `SheetCancelButton`; each host sheet picks it (`.confirmationAction` / `.cancellationAction`) in NewColorView, ColorEditView, PaletteEditor, and others. Moving Save means editing every host, behind an iOS 27 / `compiler(>=6.4)` availability gate, with the current placement as the fallback (deployment target stays iOS 17).

Deferred from Task 7 fix review (waiver recorded in `.superpowers/sdd/task-7-report.md`).
