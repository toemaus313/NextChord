You are an expert Flutter/Dart engineer working in my **NextChord** app repo.

You MUST follow the existing NextChord AI best-practices rule we’ve already set up for this project (analyze/fix loops, no unnecessary runs, minimal behavior changes, etc.). Do not override or dilute those rules—treat them as binding and additive to this request.

---

## High-Level Goal

Add robust, **configurable MIDI-based app control** with:

1. **Multi-device Bluetooth MIDI support** (simultaneous connections).
2. **Bidirectional MIDI**: the app can both **receive and send** CC/PC commands.
3. A flexible, database-backed **pedal mapping system** based on `PEDAL_MAPPINGS.md`.
4. A shared **Settings modal template** derived from the existing **MIDI Profiles** modal.
5. A new **App Control** settings modal built using that template, to configure all MIDI → app-action mappings.

This must be designed so that **new MIDI commands and new app actions can be added later with minimal code changes.**

---

## General Requirements & Constraints

- Do NOT break existing features. Preserve current MIDI behavior and existing DB structures unless a change is strictly necessary. If something must change, keep it backward compatible where possible.
- Respect existing architecture, naming conventions, and state management patterns already used in the repo.
- Apply SOLID design: isolate hardware-level / MIDI plumbing from app-level “actions” and UI.
- Use clear, typed models and enums instead of magic strings where possible.
- After each major change, run:
  - `flutter analyze` and ensure **zero errors**.
  - Any existing tests related to MIDI, settings, or DB (if they exist).
- Keep changes logically grouped and well-commented so a human developer can follow what you did.

---

## Phase 1 – Multi-Device + Inbound/Outbound MIDI

1. **Inspect Current MIDI Implementation**
   - Locate all MIDI and Bluetooth-related code (plugins used, services, managers, and any existing settings/modals).
   - Summarize (in comments or a short internal doc) the current limitations, especially:
     - Whether only one Bluetooth MIDI device can be connected at a time.
     - How inbound messages are currently processed.
     - Whether any outbound MIDI sending is already implemented.

2. **Enable Multiple MIDI Devices**
   - Refactor the MIDI layer into a structure that supports **multiple simultaneous MIDI devices**, e.g. a `MidiDeviceManager` that:
     - Tracks a list of connected devices (with device metadata).
     - Supports connecting / disconnecting specific devices.
     - Exposes streams / callbacks for incoming MIDI events tagged with their source device.
   - Ensure this works for **Bluetooth MIDI devices** and does not break existing behavior for whatever platforms/devices are already supported.
   - If the current plugin supports multiple connections but code is artificially limiting to one, remove that limitation. If the plugin itself is a blocker, refactor as minimally as possible to a plugin that supports multi-device—but avoid a massive rewrite unless absolutely necessary.

3. **Inbound MIDI (CC & PC)**
   - Ensure the app can listen for:
     - **Control Change (CC)** events.
     - **Program Change (PC)** events.
   - Normalize inbound MIDI messages into a clean model, e.g.:

     ```dart
     class MidiMessage {
       final MidiDeviceRef device;
       final MidiMessageType type; // cc, pc, noteOn, etc.
       final int channel;
       final int number; // CC number or PC number
       final int? value; // for CC; PC may not need value
       final DateTime timestamp;
     }
     ```

   - Make this model the central representation used by higher-level logic.

4. **Outbound MIDI (CC & PC)**
   - Add an outbound API so the app can send CC/PC commands to **any connected MIDI device**, not just one:
     - E.g., `MidiDeviceManager.send(MidiMessage message)` or explicit helpers:
       - `sendControlChange(device, channel, number, value)`
       - `sendProgramChange(device, channel, programNumber)`
   - Keep this API generic and reusable so later features (e.g., sending commands when a song changes) can reuse it.

5. **Basic Safety & Error Handling**
   - Robustly handle:
     - Device disconnects.
     - Lost Bluetooth connections.
     - Cases where no devices are connected but code tries to send.
   - Provide graceful, user-friendly feedback in logs / debug messages, but avoid intrusive popups in normal operation.

---

## Phase 2 – Use `PEDAL_MAPPINGS.md` (Review & Commit to Code)

1. **Locate and Read `PEDAL_MAPPINGS.md`**
   - Find the `PEDAL_MAPPINGS.md` doc in the repo.
   - Extract from it:
     - The known pedal actions.
     - Any already-defined mapping structures.
     - Any naming conventions or DB model hints.

2. **Align With Existing DB Schema**
   - Find where “actions” were migrated to the DB (tables, models, DAOs, etc.).
   - Your goal is to **reuse and extend** that existing abstraction rather than invent a parallel system.

3. **Define a Stable App-Action Model**
   - Define a central, type-safe representation of “things the app can do when a pedal/MIDI event occurs”, e.g.:

     ```dart
     enum AppControlActionType {
       nextSongInSetlist,
       previousSongInSetlist,
       scrollUp,
       scrollDown,
       startMetronome,
       stopMetronome,
       toggleMetronome,
       startAutoscroll,
       stopAutoscroll,
       toggleAutoscroll,
       // ... anything already defined in PEDAL_MAPPINGS.md
     }
     ```

   - Make sure this set is **extensible**:
     - New actions can be added in one place.
     - Mapping and UI logic use this enum, not hardcoded strings.

4. **Mapping Model (DB-backed)**
   - Based on `PEDAL_MAPPINGS.md` and the existing DB, either:
     - Confirm the current mapping table/model is sufficient, or
     - Introduce/extend a mapping table like:

       ```sql
       pedal_mappings(
         id,
         name,
         device_id (nullable or wildcard),
         message_type,   -- cc or pc
         channel,
         number,
         value_min,
         value_max,
         action_type,    -- maps to AppControlActionType
         action_params,  -- JSON/serialized, for future extensibility
         is_enabled
       )
       ```

   - Implement a Dart model that mirrors this and integrates with your DB layer (e.g., Drift).

---

## Phase 3 – Modal Template from MIDI Profiles Modal

1. **Identify the MIDI Profiles Modal**
   - Locate the **MIDI Profiles** Settings modal widget/screen.
   - Carefully review its layout and behavior:
     - Header style, title, close/back buttons.
     - Content padding and scrolling.
     - Save/Cancel actions.
     - Responsive behavior (desktop vs tablet vs phone).

2. **Extract a Reusable Modal Template**
   - Create a reusable widget (e.g., `AppSettingsModalScaffold`) that encapsulates:
     - Common header (title, optional subtitle).
     - Optional back button or close icon.
     - Standardized Save/Cancel or Apply actions.
     - Consistent theming and padding.
     - Scrollable content region.
   - Refactor the MIDI Profiles modal to **use** this new template without changing its user-visible behavior.

3. **Apply Template to Existing Modals**
   - Identify other modals in the app (Settings modals, profiles, etc.).
   - Incrementally refactor them to use the new template where reasonable.
   - Ensure:
     - Behaviors remain the same.
     - There are no layout regressions.
     - Any unique logic remains intact (only the scaffolding/template is shared).

4. **Acceptance Criteria for Template**
   - All major modals now share the same layout & style.
   - It is easy to add a new modal by using this template without duplicating boilerplate.
   - No new layout or routing bugs introduced.

---

## Phase 4 – Build the New “App Control” Settings Modal & Wiring

1. **Create “App Control” Settings Modal**
   - Implement a new Settings modal named **“App Control”**, built using the template from Phase 3.
   - It should live in the Settings area alongside existing modals (MIDI Profiles, etc.).

2. **App Control Modal Functionality**
   - The modal should let the user:
     - See the list of **connected MIDI devices** (or at least those relevant for app control).
     - Create/edit/delete **pedal mappings** (rows) that:
       - Choose one or more devices (or “any device”).
       - Specify MIDI message type (CC or PC).
       - Configure channel, number, and (for CC) optional value range.
       - Map the MIDI event to an `AppControlActionType` (from Phase 2).
       - Enable/disable individual mappings.
   - Make sure UI is **easy to extend** if we add more actions or more advanced conditions later.

3. **Runtime Wiring: MIDI → App Actions**
   - Implement a central handler that:
     - Listens to the normalized inbound `MidiMessage` stream.
     - For each inbound event:
       - Looks up active mappings that match:
         - Device (or “any”).
         - Message type.
         - Channel.
         - Number.
         - Optional value range (for CC).
       - Triggers the corresponding `AppControlActionType` in the app.
   - Implement the actual actions for at least the following (using existing internal APIs where possible):
     - Next / previous song in current setlist.
     - Scroll up / scroll down in the viewer.
     - Start / stop / toggle metronome.
     - Start / stop / toggle autoscroll.
   - Where relevant, plug into existing state management rather than adding ad-hoc logic.

4. **Outbound MIDI Integration (Optional for Now, but Ready)**
   - Ensure that the same infrastructure can later be used to send MIDI out based on app events.
   - If it’s low effort and safe, add at least a basic example:
     - E.g., when the current song changes, optionally send a Program Change to a selected device (configurable).
   - This should be optional and configurable (don’t spam MIDI by default).

5. **UX & Safety Considerations**
   - Provide sensible defaults (e.g., no mappings enabled by default).
   - If a mapping is misconfigured, fail silently rather than crashing.
   - Make it obvious in the UI where to configure devices vs. mappings.

---

## Final Cleanup & Documentation

1. Run `flutter analyze` and ensure **zero errors**.
2. Run any existing tests; add small tests where it makes sense (e.g., mapping resolution logic).
3. Update or create docs:
   - Update `PEDAL_MAPPINGS.md` if needed to reflect the new DB-backed mapping model and UI.
   - Create or update any developer-facing documentation explaining:
     - How to add a new `AppControlActionType`.
     - How it gets surfaced in the App Control modal.
     - How to wire it into the action dispatcher.

4. As you go, leave concise comments in the code where the architecture might not be obvious (e.g., why we model mappings a certain way, or how multiple devices are handled).

When you’re done, the app should:

- Be able to connect to **multiple MIDI devices** at once.
- **Receive and send** CC/PC messages.
- Let me configure MIDI pedal actions in a **new App Control modal**, based on a shared modal template.
- Use a **flexible, DB-backed mapping system** derived from `PEDAL_MAPPINGS.md` that is easy to extend with new commands and actions.
