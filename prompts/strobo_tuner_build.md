You are working in my Flutter app. I already have a working guitar tuner feature with audio input and pitch detection. Do not modify, refactor, or replace any of the existing underlying tuner logic (audio input, pitch detection, frequency-to-note mapping, etc.).

Your task is only to change the look and feel of the tuner to use a virtual stroboscopic-style tuner display (like Peterson strobe tuners).

High-level behavior

Implement a reusable Flutter widget that creates a visual strobe effect driven by the existing “how many cents off” value from the tuner:

There is a band/strip of repeating dots or segments.

The band appears to scroll left/right continuously.

The further the detected pitch is from in-tune (in cents), the faster the dots scroll.

When the pitch is in tune (within a small dead-zone in cents), the dots appear to stop moving.

Direction of movement indicates flat vs sharp (e.g., one direction = flat, the other = sharp).

You can assume that somewhere in the existing tuner UI/state we already have a continuously updating “cents offset” value (negative = flat, positive = sharp). If that value isn’t explicit yet, expose it from the existing tuner logic via the most minimal change possible, without changing how the tuner actually works.

Requirements

Do NOT change the underlying tuner logic

Don’t change audio input handling.

Don’t change pitch detection or note detection.

Don’t change any existing data models or services except:

If necessary, just expose a centsOffset value that the UI can read.

The tuner should behave exactly the same in terms of detection; we are only layering on a new UI representation.

Create a strobe tuner UI widget

Add a new reusable widget, e.g. StrobeTunerStrip (you can choose the exact name, but keep it clear).

Public API concept:

It takes a centsOffset (double, negative = flat, positive = sharp).

It supports a deadZoneCents parameter to decide what counts as “in tune”.

Implement the strobe effect:

Use a time-based animation (Ticker/AnimationController) so the band scrolls smoothly.

Map centsOffset → scroll speed:

abs(centsOffset) small → slow movement.

abs(centsOffset) large → faster movement.

Within deadZoneCents, speed = 0 so the pattern looks “frozen”.

Direction of scrolling changes depending on sign of centsOffset (flat vs sharp).

Visual style

Use a horizontal strip with repeated dots or narrow rectangles.

Use colors that will fit a dark music app (e.g., dark background, cyan/blue or green dots).

When in tune (within dead zone), optionally shift color or intensity (e.g., brighter green) to give a clear “locked” visual.

Use CustomPainter (or another efficient approach) so the animation is smooth and doesn’t cause unnecessary rebuilds.

Integrate into the existing tuner screen

Locate the current tuner UI/screen.

Replace or augment the current “in/out of tune” visual indicator with this new strobe widget, using the existing cents offset value.

The new widget should update in real-time as the tuner updates.

Don’t remove any useful existing info (like note name, detected frequency, etc.); just integrate the strobe as the main tuning indicator.

Code quality & structure

Keep the new UI code well-organized and documented.

Avoid breaking any public APIs the rest of the app might rely on.

If you need to refactor the tuner UI tree, keep the changes minimal and focused on layout/visuals only.

Before and after steps

First, scan the project and:

Identify the existing tuner screen and where the “cents off”/tuning accuracy value is derived from.

Briefly summarize what you found (file names and key classes).

Then:

Propose a short plan for how you’ll integrate the StrobeTunerStrip (or equivalent) into the existing tuner screen.

Implement the plan and show me the final diff.

Again: do not modify the core tuner logic or behavior. Only adjust the UI so the tuner presents as a stroboscopic-style tuner where dots move faster the further from in-tune the string is, and stop when it’s in tune.