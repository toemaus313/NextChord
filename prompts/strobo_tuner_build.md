# NextChord – Peterson-Style Strobe Tuner Redesign Prompt

You are working in my Flutter app. I already have:

- A working guitar tuner feature with audio input and pitch detection.
- Existing tuner logic that produces a cents offset (negative = flat, positive = sharp) and a current/target string or note.

You are NOT creating the tuner logic from scratch. Your job is to design and implement a new Peterson-style virtual strobe display and an updated tuner UI, without changing the underlying tuner logic.

---

## High-level goals

1. Make the strobe animation look and behave more like a Peterson strobe tuner:
   - Clean, evenly spaced repeating segments/bars.
   - Very smooth, uniform motion.
   - Clear directional indication for sharp vs flat.
   - Strong, obvious "lock" when the note is in tune.

2. Change the Guitar Tuner modal so that only the currently targeted string is shown:
   - Only the current target string should be displayed in the main "string" area under the strobe strip.
   - That string should be visually prominent and clearly marked as active.

3. Do NOT modify or refactor the core tuner logic:
   - No changes to audio input, pitch detection, frequency-to-note mapping, or data models, beyond minimally exposing centsOffset and currentTargetString/currentNote to the UI.

---

## Constraints

Do NOT:

- Change audio input handling.
- Change or replace pitch detection.
- Change note detection or mapping logic.
- Break any existing public APIs or data models used by the tuner feature.

You MAY:

- Expose a minimal `centsOffset` value for the UI if it is not already available.
- Expose a `currentTargetString` / `currentNote` property if needed for the UI.
- Refactor UI/widget/layout code only as much as needed to improve visuals, integrate the strobe strip, and show only the active string.

---

## Task 1 – Scan and summarize the current implementation

1. Locate:
   - The Guitar Tuner modal/screen file(s).
   - Any existing strobe-style tuner UI implementation (CustomPainter/AnimationController/etc).
   - Where the cents offset value is computed or exposed.
   - Where the list of 6 strings is rendered in the tuner modal.

2. Briefly summarize (in comments or one output block):
   - Key files/classes involved.
   - How the current tuner UI gets the cents offset.
   - How the 6-string list is currently displayed and updated.

Do not change behavior in this step; just document.

---

## Task 2 – Implement a Peterson-style strobe tuner widget

You are creating/refining a strobe strip widget that behaves like a Peterson tuner:

> A virtual stroboscopic strip where a regular pattern’s apparent motion speed depends on how many cents off the note is, and stops when in tune.

### Widget API

Create or refine a reusable widget, e.g. `StrobeTunerStrip`:

- `final double centsOffset;   // negative = flat, positive = sharp`
- `final double deadZoneCents; // e.g. 2–5 cents, configurable`
- Optional visual configuration parameters if needed (but keep sensible defaults).

### Animation behavior

Use a time-based animation (AnimationController + TickerProviderStateMixin):

- The animation runs continuously while the tuner is active.
- Each frame uses a phase value that advances over time based on centsOffset.

Pseudo-behavior:

```dart
final double absCents = centsOffset.abs();
const double minSpeed = 0.1; // example
const double maxSpeed = 2.0; // example
const double maxCents = 50.0;

final double normalized = (absCents.clamp(0, maxCents)) / maxCents;
double speed = minSpeed + (maxSpeed - minSpeed) * normalized;

if (absCents <= deadZoneCents) {
  speed = 0.0;
}

final int direction = centsOffset >= 0 ? 1 : -1;
// phase is a double stored in state, updated each tick: phase += dt * speed * direction;
```

- Direction of movement depends on sign of centsOffset:
  - Positive (sharp) → bars move in one direction (e.g., right).
  - Negative (flat) → bars move in the opposite direction (e.g., left).
- When abs(centsOffset) <= deadZoneCents, speed must be exactly 0 so the pattern is frozen.

Use CustomPaint + CustomPainter so that only painting work happens each frame (no heavy rebuilds).

---

## Task 3 – Strobe pattern geometry (very important)

Previous attempts with random bar widths and varying cyan shades are NOT acceptable.

You must render a very regular, repeating pattern:

- Use evenly spaced vertical bars:
  - All bright bars have the same width (e.g., 6–10 logical pixels; choose a constant).
  - All gaps between bright bars have the same width (e.g., 4–8 logical pixels; choose a constant).
  - There should be no per-bar variation in width or spacing.

- Pattern logic (explicit):
  - Define `barWidth` and `gapWidth` constants.
  - Define `tileWidth = barWidth + gapWidth`.
  - Maintain a continuously updated `phase` in the range [0, tileWidth).
  - In the painter:
    - For each integer i, compute `double x = i * tileWidth + phase;`.
    - For each x that intersects the visible strip:
      - Draw a single bright bar from `x` to `x + barWidth` (clamped to the canvas).
      - Leave the remaining gap as dark background.
  - The visual result should be identical bright bars marching across the screen.

Remove any logic that:
- Varies color by bar index.
- Varies width or spacing by bar index.
- Applies random gradients per bar.

The pattern must look like a single clean row of identical, evenly spaced vertical bars sliding smoothly left/right.

---

## Task 4 – Color and visual styling (critical)

Use a dark theme that fits the rest of the tuner UI. Be precise and consistent.

### Background

- Very dark, nearly black (e.g., #050814 – #0A0F1A).
- Solid or a very subtle vertical gradient, but it should clearly read as a dark strip behind the pattern.

### Out-of-tune bars (moving state)

- Color: a single cool, bright cyan/blue that contrasts strongly with the background.
  - Examples: #18B7FF, #26D9FF (or similar).
- All bars must use the same solid color in the moving/out-of-tune state:
  - Do NOT vary hue per bar.
  - Do NOT vary opacity per bar.
  - Do NOT apply per-bar gradients.

### In-tune bars (locked state)

- Condition: abs(centsOffset) <= deadZoneCents.
- Behavior:
  - The phase stops changing (speed = 0), so the pattern is frozen.
  - Change bar color to a bright, saturated green.
    - Examples: #3CFF82, #4CFF4C.
  - You may slightly increase opacity or add a very subtle outer glow/halo to emphasize the locked state.
- Do NOT flash or pulse the bars; rely on motion stopping + color change.

### Flat vs sharp

- Direction is the only difference:
  - Sharp → bars move one way.
  - Flat → bars move the opposite way.
- Do NOT change color for flat vs sharp. Keep the palette fixed:
  - Cyan/blue for moving (out of tune, either direction).
  - Green for frozen (in tune).

### General rules

- Avoid pastel, low-contrast, or muddy colors.
- The strip must remain clearly visible and distinct from the modal background.
- Keep the palette minimal and consistent: dark background, cyan/blue moving bars, green locked bars.

---

## Task 5 – Show only the current target string in the tuner modal

Currently, the modal shows all 6 strings below the strobe UI. Redesign that area so:

- Only the current target string is shown in the main "string" section under the strobe strip.
- That string should be visually prominent and clearly labeled.

### Determine current target string

Use whatever concept already exists:

- If there is an explicit selected/target string (user taps E/A/D/etc.), use that.
- If not, use the string/note that the tuner logic already considers "current" or "closest".

If necessary, add a minimal UI-level property:

- `currentTargetString` (or similar) exposed from the tuner controller/state.
- Do NOT modify the pitch detection itself; just surface what is already being computed.

### UI updates

- Replace the 6-string list area with a single focused display of the active string:
  - Large string name/note (e.g., "E2", "A2").
  - Optional label such as "Currently tuning" or "Target string".
  - Optional icon/badge to show it is active.
- Do NOT show the other strings in that section anymore.
- Keep other useful info (note name, detected frequency, etc.) visible elsewhere in the modal.

If there is a different UI location where the user needs to see or select all 6 strings, that can remain unchanged. Only the main area under the strobe strip should show just the active string.

---

## Task 6 – Integrate into the tuner screen

In the Guitar Tuner modal/screen:

1. Ensure you have access to:
   - `centsOffset` (double).
   - `deadZoneCents` (reasonable default, e.g. 3–5 cents).
   - `currentTargetString` / `currentNote` info.

2. Integrate the strobe strip:
   - Replace the old in-tune/out-of-tune visual with the new `StrobeTunerStrip` widget.
   - Feed it the live centsOffset.
   - Ensure it repaints smoothly via animation + CustomPainter.

3. Integrate the single-string display:
   - Remove or hide the multi-string list from the main tuner area.
   - Add a "Current string" section under the strobe strip showing only the target string.

4. Preserve all other useful information (frequency, note labels, status text, etc.).

---

## Task 7 – Code quality and diffs

- Keep new UI code well organized (separate widgets/painters).
- Respect existing best-practice and debugging rules (e.g., myDebug wrappers).
- Avoid introducing performance problems; no heavy rebuilds in the animation loop.

When finished:

1. Output a short summary of what you changed and which files you touched.
2. Show the key diffs for:
   - The new/updated `StrobeTunerStrip` widget and painter.
   - The tuner modal layout where the strip and current string are integrated.
   - Any controller/state changes that expose centsOffset or currentTargetString.

Remember: do NOT change the core tuner logic. Only improve the UI so that:

- The strobe looks and feels like a Peterson-style tuner (regular bars, cyan when moving, green when locked, speed/direction based on cents).
- Only the currently targeted string is shown under the strobe strip in the Guitar Tuner modal.
