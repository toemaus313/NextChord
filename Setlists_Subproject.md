# Setlists Subproject

## Goal
Polish and extend the new setlist experience so musicians can organize shows end-to-end: browse setlists from the sidebar, fine-tune per-song settings, structure sets with dividers, and eventually rehearse/play through full performances.

---

## Workstream Overview

| ID | Priority | Area | Summary |
| --- | --- | --- | --- |
| T1 | High | Navigation & State | Wire the global sidebar to the setlists grid, ensure provider lifecycle, and support deep linking into the editor. |
| T2 | High | Editor UX | Add per-song capo & transpose overrides inside the dialog, including UI affordances and validation. |
| T3 | Medium | Editor UX | Support section dividers (add, rename, reorder) so users can break sets into chunks. |
| T4 | Medium | Playback | Build a basic “Run Setlist” view that steps through songs applying overrides, tracking progress. |
| T5 | Medium | Polish & QA | Cover regression tests, image storage cleanup, and doc updates once the above land. |

---

## Detailed TODOs & Cascade Prompts

### T1 — Sidebar & Navigation
- [ ] Add a **Setlists** entry in `global_sidebar.dart` that loads `SetlistsScreen` in the main pane when selected.
- [ ] Ensure `SetlistProvider` loads once (e.g., preload in `HomeScreen` init) and that navigating back to songs rehydrates state.
- [ ] Provide breadcrumbs or context in the main pane when a setlist is opened.

**Prompt to give Cascade:**
> “Open `global_sidebar.dart` and wire the Setlists menu item so the main content navigates to `SetlistsScreen`. Ensure the provider lifecycle matches SongProvider (lazy load, refresh on focus). Update HomeScreen/AppWrapper as needed so returning to songs still works.”

### T2 — Per-song Capo & Transpose Controls
- [ ] In `SetlistEditorDialog`, add per-song settings button (e.g., trailing icon) that opens a mini-form for capo & transpose overrides.
- [ ] Persist overrides into `SetlistSongItem` (fields already exist) and reflect them in the list UI (badges/labels).
- [ ] Validate values (range, numeric) and allow “Use song default” option.

**Prompt:**
> “Enhance `SetlistEditorDialog` so each song row exposes Setlist-specific capo/transpose overrides. Implement a popover/dialog to edit values, store them in `SetlistSongItem`, and show chips when overrides are active.”

### T3 — Section Dividers
- [ ] Allow adding divider items with custom labels.
- [ ] Render divider rows distinctly and include them in drag-and-drop ordering.
- [ ] Store divider items via existing `SetlistDividerItem` serialization.

**Prompt:**
> “Update `SetlistEditorDialog` to support section dividers: add an ‘Add Divider’ action, allow editing the label, show them in the list with unique styling, and include them in the serialized items list so the repository already handles them.”

### T4 — Setlist Playback View
- [ ] Create a `SetlistPlayerScreen` that shows the current song, next song, and controls to advance/rewind.
- [ ] Apply the setlist-specific capo/transpose overrides when navigating to each song (probably reusing `SongViewerScreen`).
- [ ] Provide entry points from `SetlistsScreen` and possibly the editor to start playback.

**Prompt:**
> “Introduce a `SetlistPlayerScreen` that steps through setlist items, applying per-song transpose/capo overrides when loading `SongViewerScreen`. Add a ‘Play Setlist’ CTA on the setlist card/detail that launches this flow.”

### T5 — Polish, Testing, & Docs
- [ ] Add widget/unit tests covering repository serialization (with dividers & overrides) and editor interactions where feasible.
- [ ] Clean up unused image files when a setlist image is replaced or the setlist is deleted.
- [ ] Update `SETLIST_FOUNDATION.md` (or a new doc section) summarizing the implemented UX and instructions for contributors.

**Prompt:**
> “Add regression coverage for setlist serialization (song items + dividers + overrides), handle orphaned images on setlist deletion/image replacement, and document the finalized UX in `SETLIST_FOUNDATION.md`.”

---

## Execution Notes
- Keep changes scoped per task; each prompt above is designed for a single Cascade session.
- Run `dart run build_runner build --delete-conflicting-outputs` whenever Drift schema files change.
- Prefer checking in assets (icons, placeholders) under `assets/setlists/` if new imagery is needed.
- Coordinate with future playback work so overrides stay in sync with `SongViewerScreen` features.
