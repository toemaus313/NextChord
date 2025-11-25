You are an expert Flutter/Dart engineer working in my **NextChord** app.

## High-Level Goal

I already have a **MIDI App Control framework** and an **App Control modal** where users can map incoming MIDI commands (CC/PC/etc.) to a list of Actions. Those Actions currently exist as *placeholders only* – no real functionality is wired up yet.

Your job:

1. Investigate the existing MIDI app control implementation and App Control modal.
2. Implement the actual functionality for each Action listed below.
3. Wire the configured Actions to their behavior in the app.
4. Respect my **Best Practices** (small, modular code) and **Debug Rules** (no stray debug noise).

The end result should be:
- CLEAN, compiling project (run the comp-error-loop workflow for debugging)
- No behavior regressions for existing non-MIDI controls
- MIDI-mapped actions behave identically to their UI equivalents (or better) and should call existing methods wherever possible.

---

## Step 1 – Recon / Existing Code

1. Locate and review:
   - The App Control modal UI and any related view models/controllers.
   - The MIDI handling layer where inbound Bluetooth MIDI messages are decoded and mapped to Actions.
   - Any existing enums / models representing Actions (e.g. `AppControlAction` or similar).
   - `PEDAL_MAPPINGS.md` and any other documentation describing actions and expected behavior.
2. Sketch out (mentally) the the current flow:
   - Where inbound MIDI messages are received (e.g., a Bluetooth MIDI service).
   - How they are associated with configured mappings in the DB.
   - Where an “Action” is currently decided but not executed.
3. Identify the **single best place** in the architecture to centralize action execution, e.g. a service like:
   - `AppControlActionExecutor`, or
   - an extension of an existing coordinator/service that already knows how to talk to the viewer, metronome, autoscroll, etc.

> Do NOT scatter “do-this-action” logic through multiple widgets. There should be **one central action dispatcher** that UI and MIDI can both call.

---

## Step 2 – Create / Refine the Action Execution Layer

Create (or refine) a central, testable layer that can execute any action by enum / ID, e.g.:

```dart
enum AppControlAction {
  previousSong,
  nextSong,
  previousSection,
  nextSection,
  scrollUp,
  scrollDown,
  scrollToTop,
  scrollToBottom,
  toggleMetronome,
  repeatCountIn,
  toggleAutoscroll,
  autoscrollSpeedFaster,
  autoscrollSpeedSlower,
  toggleSidebar,
  transposeUp,
  transposeDown,
  capoUp,
  capoDown,
  zoomIn,
  zoomOut,
  // plus any existing actions already defined
}
```

Then implement something like:

```dart
class AppControlActionExecutor {
  Future<void> perform(AppControlAction action) async {
    switch (action) {
      case AppControlAction.previousSong:
        return _goToPreviousSong();
      // ...etc
    }
  }

  // Each helper method should be small and delegate to existing services
  // (song navigation, viewer, metronome, autoscroll, layout/sidebar, etc.)
}
```

**Key rules:**

- **Do not** put large blocks of logic in the `switch`. Each case should call a short, focused helper method.
- Reuse existing services / controllers / blocs / providers wherever possible instead of duplicating logic.
- If new services are needed, keep them small and injectable/testable.

---

## Step 3 – Wire MIDI → Action Executor

1. Find the code where MIDI commands are translated from (device, channel, cc/pc, value) → “Action mapping” (based on user’s App Control configuration).
2. Replace any placeholder logic so that once an `AppControlAction` is determined, it calls the centralized executor:
   - Either directly: `actionExecutor.perform(mappedAction)`
   - Or via a mediator the architecture already uses.
3. Ensure:
   - Existing non-MIDI functionality (buttons, keyboard shortcuts, etc.) either:
     - also use this same executor (preferred), or
     - remain functional and consistent with these new behaviors.

Where appropriate, refactor existing UI handlers to call the **same** executor instead of having parallel implementations.

---

## Step 4 – Implement Each Action’s Behavior

Use the app’s existing architecture and utilities. Do **not** reimplement things that already exist – instead, **call the existing code** (e.g., song navigation, viewer scroll, zoom, metronome service, autoscroll service, etc.).

Below is the precise behavior for each action:

### Song Navigation

**Previous Song**
- Behavior:
  - Go to the previous song in the **active setlist**.
  - If at the **first** song, or if **no setlist** is active → **do nothing**.
- Implementation notes:
  - Reuse existing setlist navigation logic if it exists.
  - Make sure UI updates (viewer, title, etc.) just as if user tapped the UI for previous song.

**Next Song**
- Behavior:
  - Go to the next song in the **active setlist**.
  - If at the **last** song, or if **no setlist** is active → **do nothing**.
- Implementation notes:
  - Same as above, just for forward direction.
  - Ensure any “current song” state and UI selection are kept in sync.

---

### Section Navigation Within a Song

**Previous Section**
- Behavior:
  - Move to the **previous section marker** in the currently open song.
  - Section markers include:
    - Any existing section/marker constructs already used in the viewer.
    - **AND** any `{comment:xxxxxxxx}` ChordPro tags – treat each such comment as a section stop for navigation purposes.
  - If already at the first section (top) → do nothing.
- Implementation notes:
  - Reuse any existing code that computes “sections” or anchors, if present.
  - Otherwise:
    - Build an ordered list of section offsets/indices (including comment markers).
    - Maintain current position and jump to the previous section’s offset.
  - Scrolling should be smooth, consistent with how the viewer normally scrolls to sections.

**Next Section**
- Behavior:
  - Move to the **next section marker** in the song (same definition as above).
  - If already at the last section → do nothing.
- Implementation notes:
  - Mirror the logic for Previous Section, stepping forward in the ordered list of section anchors.

---

### Scrolling

**Scroll Up**
- Behavior:
  - Smoothly scroll **30% of the visible viewport height upward**.
- Implementation notes:
  - Use the existing smooth scrolling logic for the viewer.
  - Ensure this works whether autoscroll is running or not (if there is an interaction, be explicit about how it behaves; default should be intuitive).

**Scroll Down**
- Behavior:
  - Smoothly scroll **30% of the visible viewport height downward**.

**Scroll to Top**
- Behavior:
  - Smoothly scroll to the very top of the song.

**Scroll to Bottom**
- Behavior:
  - Smoothly scroll to the very bottom of the song.

---

### Metronome & Count-In

**Toggle Metronome**
- Behavior:
  - Toggle the metronome **on/off**.
  - **Skip any count-in** (even if configured).
  - When turning on from this action, start the metronome immediately.
- Implementation notes:
  - If the metronome service currently always runs a count-in, refactor the underlying API to support:
    - `start({bool skipCountIn = false})`
  - Existing UI buttons should still behave as before; only this action should explicitly skip count-in.

**Repeat Count-In**
- Behavior:
  - Run the count-in **only**, as configured in settings (1 measure or 2 measures), with the existing onscreen count visuals.
  - If **no count-in** is configured:
    - Run a **1-measure** count-in by default.
  - After the count-in, **do not** continue the metronome unless that’s already the app’s standard behavior for “repeat count-in”.
- Implementation notes:
  - Use the same visuals and timing as the UI-based count-in.
  - Consider adding a method to the metronome service like `playCountInOnly()`.

---

### Autoscroll & Autoscroll Speed

**Toggle Auto-scroll**
- Behavior (this includes a **logic change** to the existing autoscroll feature):
  1. **First time** the autoscroll is turned ON after loading a song:
     - Perform the configured count-in (1 or 2 measures, with onscreen count).
     - Then start autoscroll.
  2. Subsequent toggles:
     - **Do not** repeat the count-in; just toggle autoscroll start/stop directly.
  3. Reset this “count-in has run” state whenever:
     - The user exits the song, or
     - A different song is loaded.
- Implementation notes:
  - Introduce a per-song flag, e.g. `hasRunAutoscrollCountIn` stored in the appropriate controller/state.
  - Ensure both:
    - The UI button for autoscroll
    - And the MIDI `Toggle Auto-scroll` action
    use the **same** logic so behavior is consistent.
  - Make sure metronome count-in and autoscroll remain in sync with existing tempo settings.

**Autoscroll Speed Faster**
- Behavior:
  - Decrease the **song duration** used by autoscroll by **15 seconds**.
  - This effectively makes autoscroll scroll **faster**.
  - Changes must be:
    - **Immediate**, even if autoscroll is already running.
    - **Persisted to the song** (so reopening the song remembers this adjusted duration).
- Implementation notes:
  - Reuse existing persistence mechanism for song duration/autoscroll settings.
  - Respect any existing min/max constraints already defined in the code (do not introduce arbitrary new ones unless absolutely necessary and documented).

**Autoscroll Speed Slower**
- Behavior:
  - Increase the **song duration** used by autoscroll by **15 seconds**.
  - Persist the new duration to the song.
- Implementation notes:
  - Same as above, in the slower direction.
  - Ensure changes are applied live if autoscroll is currently active.

---

### Layout / Sidebar

**Toggle Sidebar**
- Behavior:
  - Show/hide the **global sidebar** that is used for navigation (songs, settings, setlists, etc.).
- Implementation notes:
  - Reuse the existing state management for showing/hiding the sidebar (e.g. a provider, bloc, or layout controller).
  - Do **not** introduce new layout mechanisms; simply trigger the same behavior used by the current sidebar toggle UI.

---

### Transpose & Capo

For all of these, **reuse the existing logic** used by the UI controls (transpose and capo buttons). Do not create new transposition logic that can drift from the rest of the app.

**Transpose Up**
- Behavior:
  - Transpose the key **up by one half-step**.
  - Persist this new transposition to the song.
- Implementation notes:
  - Call whichever method the UI uses for a +½ step transpose.
  - Ensure that the viewer, any chord diagrams, and metadata reflect the new transposition.

**Transpose Down**
- Behavior:
  - Transpose the key **down by one half-step**.
  - Persist the new transposition to the song.

**Capo Up**
- Behavior:
  - Increase capo setting by **1**.
  - Persist to the song.
- Implementation notes:
  - Again, reuse the same function used by UI to handle capo changes (including any chord-label regeneration, etc.).

**Capo Down**
- Behavior:
  - Decrease capo setting by **1**.
  - If capo is already at **0**, take **no action**.
  - Persist changes to the song.

---

### Zoom / Text Size

The app already has pinch-to-zoom support. Use that same underlying mechanism rather than implementing a new zoom system.

**Zoom In**
- Behavior:
  - Increase text size / zoom level (equivalent to a small “zoom in” step).
- Implementation notes:
  - Call existing functions used by pinch-to-zoom or zoom buttons.
  - Keep steps consistent with existing UI behavior.

**Zoom Out**
- Behavior:
  - Decrease text size / zoom level (equivalent to a small “zoom out” step).
- Implementation notes:
  - Respect any min/max zoom limits already in place.

---

## Best Practices & Debug Rules (Important)

Follow these rules very carefully:

1. **Modular code, small functions**
   - Prefer many small, focused methods over a few large ones.
   - Keep widget build methods and services readable; extract helpers if needed.
2. **Reuse existing architecture**
   - Do not bolt on new global singletons or ad-hoc state.
   - Integrate with existing services, providers, blocs, or controllers.
3. **Debug / Logging**
   - Do **not** add stray `print` or debugging clutter.
   - If temporary debug logging is absolutely necessary:
     - Use the project’s existing logging utilities (if any).
     - Remove or disable them before finalizing the task.
4. **No behavior regressions**
   - Existing keyboard/mouse/touch behavior should remain unchanged except where explicitly requested.
   - MIDI control should complement, not replace, current interactions.

---

## Final Steps & Validation

1. Add or update **unit tests** / widget tests for:
   - The central action executor.
   - At least one test per action verifying that the correct underlying service/logic is called.
2. Run:
   - `flutter analyze`
   - `dart test`
3. Fix any issues they report.
4. Ensure the project builds successfully for all supported platforms.

When done, briefly summarize:
- Where the central action executor lives (file/class).
- How MIDI actions are now wired into it.
- Any notable decisions or edge cases you handled.
