# NextChord – Strobe Tuner Refinement Prompt (Peterson‑style + Single Target String)

You are working in my Flutter app. I **already** have:

- A working guitar tuner feature with audio input and pitch detection.
- A first-pass “strobe-style” tuner UI implementation from a previous prompt.

You are **not** creating the tuner from scratch. Your job now is to **refine and improve the existing strobe tuner UI**, not replace the underlying tuner logic.

---

## High-level goals

1. **Make the strobe animation look and behave more like a Peterson strobe tuner**  
   - Keep it original enough to avoid copying trade dress, but aim for a similar *feel*:
     - Crisp, repeating segments/dots.
     - Very smooth motion.
     - Clear directional indication for sharp vs flat.
     - Strong, obvious “lock” when the note is in tune.

2. **Change the Guitar Tuner modal so that only the currently targeted string is shown**  
   - Right now, all 6 strings are shown below the animated tuner.
   - I want **only the string being tuned** (the current “target”) displayed in that area:
     - Larger, more prominent.
     - Clearly marked as the active string.
     - Other strings should not be visible in that section.

3. **Do NOT modify or refactor the core tuner logic**  
   - No changes to audio input, pitch detection, frequency-to-note mapping, or any data models/services beyond exposing data the UI needs (like cents offset or current target string).

---

## Existing context

There is already:

- A tuner screen / modal (the Guitar Tuner modal).
- A working tuner pipeline:
  - Audio input.
  - Pitch detection.
  - Mapping detected frequency → note/string.
  - A “cents off” / tuning accuracy value in some form.
- A first implementation of a strobe-like widget (or related UI code) from a previous pass at this prompt.

You must **reuse and refine** the existing strobe tuner implementation where it makes sense, instead of throwing it away and rewriting everything.

---

## Constraints

Do **NOT**:

- Change audio input handling.
- Change or replace pitch detection.
- Change note detection or mapping logic.
- Break any existing public APIs or data models used by the tuner feature.

You **may**:

- Expose a minimal `centsOffset` value for the UI if it’s not already available.
- Expose a “current target string” / “current note” property if needed for the UI.
- Refactor UI/widget/layout code **only as much as needed** to:
  - Improve visuals.
  - Integrate the strobe strip.
  - Show only the active string.

---

## Task 1 – Scan & summarize the current implementation

1. Locate:
   - The **Guitar Tuner modal / screen** file(s).
   - The existing **strobe tuner UI implementation**, including:
     - Any `CustomPainter`/`CustomPaint` code.
     - Any `AnimationController`/`Ticker` setup.
   - Where the **“cents off” / tuning accuracy** value is computed or exposed.
   - Where the **list of 6 strings** is rendered in the tuner modal.

2. Briefly summarize in comments (or in a single block of text you output):
   - The key file(s) and classes involved (e.g. `guitar_tuner_modal.dart`, `StrobeTunerStrip`, `TunerController`, etc.).
   - How the current strobe UI is wired to the tuner logic (how it gets the cents offset).
   - How the 6-string list is currently displayed and updated.

Do **not** change any behavior yet in this step; just document where things are.

---

## Task 2 – Refine the strobe tuner to feel more like a Peterson

You are refining the **existing strobe widget** (or creating a new version that reuses its logic). The core idea:

> A virtual stroboscopic strip where the pattern’s apparent motion speed depends on how many cents off the note is, and stops when in tune.

### Public API (concept)

If a widget already exists (e.g. `StrobeTunerStrip`), refine it. If not, create one as described:

- `StrobeTunerStrip` (or similar clear name)
  - `final double centsOffset;   // negative = flat, positive = sharp`
  - `final double deadZoneCents; // e.g. 2–5 cents, configurable`
  - Optional visual configuration parameters (colors, dot size, etc.) if needed.

### Animation behavior

Use a time-based animation (e.g. `AnimationController` with a `TickerProviderStateMixin`) to animate the strip:

- The animation should run continuously while the tuner is active.
- Each frame should compute an **offset phase** for the strip based on:
  - Current time.
  - Current `centsOffset`.

Pseudo-behavior:

```dart
final double absCents = centsOffset.abs();
final double minSpeed = ...; // small but visible
final double maxSpeed = ...; // fast but not nauseating
final double maxCents = ...; // clamp, e.g. 50–100 cents

final double normalized = (absCents.clamp(0, maxCents)) / maxCents;
double speed = minSpeed + (maxSpeed - minSpeed) * normalized;
```

- If `abs(centsOffset) <= deadZoneCents`, set `speed = 0` so the pattern appears frozen.
- The **direction** of the offset should depend on sign:
  - `centsOffset > 0` (sharp) → e.g. scroll right.
  - `centsOffset < 0` (flat) → e.g. scroll left.

### Visual style – closer to Peterson

Refine the visuals to evoke a Peterson strobe tuner (without copying exact graphics):

- Use a **dark background** for the strip, fitting the app’s dark theme.
- Use bright segments/dots for the “strobe” pattern:
  - Cyan/blue or green segments on dark background (consistent with the rest of the app’s design).
- Consider these refinements to make it feel more “Peterson-like”:

  - Use **vertical columns / bars** or **tight dots** in multiple repeating cycles across the strip.
  - Add very subtle **gradient or brightness variation** to give a sense of depth.
  - Make the pattern **crisp and high-contrast** so the direction of motion is obvious.
  - When in tune (`abs(centsOffset) <= deadZoneCents`):
    - Freeze the pattern (speed = 0).
    - Optionally:
      - Change color (e.g. shift to a brighter green).
      - Increase intensity/opacity of segments.
      - Slightly scale up the strip or thicken the segments to accentuate the “locked” state.

- Rendering approach:

  - Prefer a single `CustomPaint` with a `CustomPainter` that:
    - Uses the animation’s **phase** (0–1) to offset the repeated pattern horizontally.
    - Draws a seamless repeating pattern: basically tile a pattern across the width and use the phase to shift it.
  - Avoid rebuilding the entire widget tree on every frame; only repaint via the painter.

- You can:
  - Reuse any good ideas from the existing implementation (e.g., pattern generation, painter structure).
  - Replace or refine parts that look too basic or jittery.

---

## Task 3 – Show only the currently targeted string in the Guitar Tuner modal

Right now, the tuner modal shows **all 6 strings** below the strobe UI. I want to redesign that so:

- Only the **currently targeted string** (the string the user is actively tuning) is shown in that area.
- The UI should still look clean and consistent with the rest of the app.

### Determine “currently targeted string”

Inspect the existing tuner logic/UX to decide what “targeted string” means:

- If the tuner already has an explicit concept of a **selected/target string** (e.g., user taps “E”, “A”, “D”, etc.), use that.
- If not, it might be:
  - The note that’s currently most strongly detected.
  - The string that’s closest to the current detected frequency.

Whichever is already in place, use it. If there is no clear current target, you can minimally:

- Introduce a simple UI-level notion of `currentTargetString`:
  - e.g., track the last stable detected note/string.
  - Expose it from the tuner controller/state without changing the core detection algorithm.

### UI changes

Update the tuner modal layout:

- Replace the area currently showing all 6 strings with a **single focused display** for the targeted string:
  - Example elements:
    - String name (e.g., “E2”, “A2”, etc.) in large text.
    - Maybe a label like “Currently tuning” / “Target string”.
    - Optionally a small icon/indicator that it’s active.
- Do **not** show the other 5 strings in that section anymore.
- Keep any other existing tuner info that’s useful (note name, frequency readout, etc.) visible and intact.

If there is a place elsewhere in the app where all 6 strings are needed (e.g., for selection), that’s fine—keep that behavior—but the **main area under the strobe strip** should only show the active string.

---

## Task 4 – Integrate the refined strobe and single-string display

In the tuner screen/modal:

1. Ensure you have access to:
   - `centsOffset` (double).
   - `deadZoneCents` (some reasonable default; you can make it configurable if needed).
   - `currentTargetString` / current note or string info.

2. Wire the strobe strip:

   - Replace the existing “in/out of tune” visual with the improved `StrobeTunerStrip` (or equivalent widget).
   - Feed it the live `centsOffset`.
   - Ensure it rebuilds or repaints smoothly as the tuner updates.

3. Update the string display:

   - Remove or hide the UI that shows all 6 strings in the main tuner area.
   - Add a dedicated section under the strobe strip that shows **only the current target string**, with a design consistent with the rest of the tuner UI.

4. Keep:

   - Note name display.
   - Detected frequency display.
   - Any other existing readouts that are useful to the user.

Do not remove information that is helpful for tuning; just restructure that specific string list area.

---

## Task 5 – Code quality, structure, and non-breaking changes

- Keep new UI code well-organized (e.g., separate reusable widgets, painters).
- Do not break any existing public APIs that other parts of the app might depend on.
- If you refactor:
  - Keep changes localized to the tuner UI code and any associated state/controllers.
- Make sure the animation is efficient and doesn’t cause jank:
  - Use `CustomPainter`/`CustomPaint` correctly.
  - Avoid excessive allocations or rebuilds inside the animation loop.

If the project has existing rules for debugging (e.g., `myDebug` wrappers) or best practices (per `.windsurf` rules), respect them when adding logging or comments.

---

## Task 6 – Plan, implement, and show diffs

1. After you scan the codebase (Task 1), output a **short plan** that includes:
   - Files/classes to modify.
   - Which parts of the existing strobe widget you’ll reuse vs refine.
   - Where the `currentTargetString` and `centsOffset` are coming from.

2. Implement the changes according to the plan:
   - Refine the strobe widget.
   - Update the tuner modal layout.
   - Wire the data correctly.

3. Show me the final changes as a **clear diff**:
   - Key widget/class additions or updates (strobe painter, tuner modal UI, etc.).
   - Any new properties/fields added to expose `centsOffset` or `currentTargetString`.

Again: **do not modify the core tuner logic**. Only improve the UI so:

- The animation behaves and feels more like a Peterson strobe tuner (speed/direction driven by cents).
- Only the currently targeted string is shown under the strobe strip in the Guitar Tuner modal.
