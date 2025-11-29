You are an expert Flutter/Dart engineer working inside my **NextChord** app repo. I already have **Google Drive** sync working. I now want to add **iCloud Drive** as an additional sync target, reusing as much of the existing architecture, services, and widgets as possible.

## Critical constraints

- **Do NOT break or refactor away** the existing Google Drive sync. We are **adding** iCloud as a parallel option.
- **Reuse existing abstractions** wherever possible (services, repositories, widgets, settings models, etc.). Only create new code where the storage backend genuinely differs.
- **Respect all existing Windsurf Cascade rules**, especially:
  - **Best Practices** (small, modular files; clear naming; minimal side effects).
  - **Debugging** rules (use the established `myDebug` / debug wrapper patterns; no raw `print`).
- Do **not** remove or change my existing debug framework; extend it appropriately.

---

## High-level goal

Add **iCloud Drive** as a sync/storage backend that behaves just like Google Drive sync, with the **only difference** being where the files are stored:

1. When the user chooses **iCloud Files** as the sync target:
   - Use the same file structure and naming scheme we currently use for Google Drive:
     - Whatever we currently use for incremental sync files.
     - Whatever we currently use for full DB backup files (e.g., `nextchord_backup.db`).
   - Store these files in a **visible folder in iCloud Drive**, NOT an app-private/hidden container.
   - Create (if needed) and then always use a folder named **`NextChord`** at the **root of the user’s iCloud Drive** as seen in the iOS/macOS **Files** app.
2. The user should be able to switch between:
   - Local-only
   - Google Drive
   - iCloud Drive
   without losing the ability to use the existing sync flow.

---

## Concrete requirements

### 1. Discover and analyze current Google Drive integration

1. Search the codebase for the existing Google Drive integration:
   - Services (e.g., `GoogleDriveSyncService`, `CloudStorageService`, `StorageRepository`, etc.).
   - Any enums or models representing sync targets (e.g., `SyncTarget`, `StorageBackend`, etc.).
   - UI for selecting storage/sync targets in the Settings / Storage / Sync UI.
2. **Document your findings in comments** in a central place (e.g., a short comment block at the top of the new iCloud service file or a relevant existing service) so future devs can understand:
   - Which classes coordinate sync.
   - Where file paths and names are defined.
   - Where the Google Drive implementation plugs into the rest of the app.

> Important: Do not rename or over-refactor core Google Drive classes unless absolutely necessary. If refactoring is needed, keep changes small, safe, and well-explained in comments.

---

### 2. Add an iCloud Drive storage backend

1. Create a new storage backend/service for **iCloud Drive** that mirrors the Google Drive service’s responsibilities:
   - If we already have an abstraction (e.g., an interface or abstract class for “cloud storage”), implement a new concrete class for iCloud.
   - If not, consider introducing a **minimal** abstraction layer that both Google Drive and iCloud can implement, but keep the refactor small and localized.

2. Implementation details:
   - Ensure that the iCloud backend:
     - Uses the same file/folder naming conventions as Google Drive sync.
     - Handles incremental sync files and full DB backups in exactly the same logical way.
   - Ensure that all iCloud-specific implementation is properly **gated** to Apple platforms only (iOS/macOS).
     - On non-Apple platforms, the iCloud option should be hidden or disabled.

3. iCloud folder behavior:
   - On iOS/macOS, create and/or use a **visible** folder named `NextChord` in the **root of the user’s iCloud Drive** (as seen in the Files app).
   - Do **not** rely on an invisible / app-private container – the user should clearly see `NextChord` at the top level of iCloud Drive.
   - Make sure all NextChord sync files and DB backups are placed in this folder, in a structure that mirrors what we do for Google Drive.

> You may use appropriate Flutter plugins and platform integrations (e.g., iOS/macOS iCloud Drive APIs) to achieve a visible iCloud Drive folder. Keep platform-channel code minimal and well-isolated.

---

### 3. Integrate iCloud as a selectable sync target in the UI

1. Find the existing settings / storage / sync UI:
   - Where the user currently selects Google Drive or any other storage target.
2. Add **“iCloud Files”** (or similar wording) as a new sync target:
   - Update any enums / settings models that represent the sync backend to include an **iCloud** option.
   - Only show this option on iOS/macOS.
3. Ensure that:
   - When the user selects iCloud, all subsequent sync operations use the new iCloud backend.
   - When the user switches back to Google Drive or another target, everything still works as before.

4. Respect UX and failure modes:
   - If iCloud is not available or properly configured, show a friendly error or guidance (using existing patterns in the app).
   - Do not block the user from using the app if iCloud setup fails; they can still use local or Google Drive sync.

---

### 4. Debugging and logging (using myDebug wrappers)

You must use the existing **`myDebug`** wrappers and debug patterns defined in my Cascade rules. Do **not** add raw `print` or ad-hoc logging.

Add debug hooks at critical points, for example:

1. **When the sync target changes**:
   - Log the change from old target → new target.
   - Example (pseudo-code):
     - `myDebug.logInfo('Storage', 'Sync target changed from $oldTarget to $newTarget');`

2. **When initializing iCloud sync**:
   - Detecting and/or creating the `NextChord` folder at iCloud Drive root.
   - Logging success or error states.

3. **Before and after sync operations**:
   - Starting a sync.
   - Each upload/download of a file (or at least high-level “batch” actions).
   - Success or failure of each operation.
   - Any retry / backoff logic if present.

4. **Error handling**:
   - Wrap failures in clear debug messages using the established debug API:
     - Include the operation, relevant file path, and the exception message.
   - Make sure that errors are:
     - Logged via `myDebug`.
     - Surfaced to the user in a non-blocking, user-friendly way if appropriate.

> Important: Follow my existing **Debug Rules** about:
> - Where to place debug messages.
> - What verbosity levels to use.
> - Avoiding debug spam (only log key events and errors).

---

### 5. Code quality and best practices

While implementing this:

1. **Respect the Best Practices rules** that already exist in my `.windsurf` configuration:
   - Keep new files focused and small.
   - Use clear, descriptive naming consistent with the rest of the codebase.
   - Prefer dependency injection or existing service locators rather than creating new globals or singletons.
   - Do not introduce large “god classes” or sprawling service files.

2. Add or update unit / widget tests where it makes sense, especially:
   - For any new iCloud service abstraction.
   - For logic that selects a storage backend based on the chosen sync target.
   - For critical behaviors (e.g., constructing the correct iCloud path for the `NextChord` folder).

3. After making changes:
   - Run `flutter analyze` and fix **all** new errors and warnings introduced by this work.
   - Keep the project in a **clean, compiling state** at the end.

---

### 6. Documentation of components and interactions

As a final part of this work, **create developer-facing documentation** that explains how all components of the new storage system fit together, so I know where to look when specific problems pop up.

1. Create a concise markdown file in an appropriate location (for example: `docs/storage_architecture.md` or similar), and/or a well-structured comment block in a central service file.
2. In this document, clearly describe:
   - The **main storage / sync entry points** (e.g., which classes/functions are called when the app performs a sync).
   - The **core services/repositories** involved in:
     - Choosing a sync target.
     - Performing sync operations.
     - Interacting with local DB and cloud backends.
   - The **Google Drive backend**:
     - Key classes.
     - How it’s wired into the abstraction.
     - Where file paths and names are defined.
   - The **iCloud backend**:
     - Key classes.
     - How it’s wired into the abstraction.
     - How it locates or creates the `NextChord` folder in iCloud Drive.
   - The **UI flows**:
     - Where the user selects the sync target.
     - How that choice is persisted (settings models, enums, etc.).
     - How that choice influences which backend is used at runtime.
   - The **debugging touchpoints**:
     - Where `myDebug` hooks are placed.
     - What categories/tags are used (so I can filter logs when troubleshooting storage/sync issues).

3. Make this documentation:
   - **High-level enough** that I can get the big picture quickly.
   - **Specific enough** that, if I have a bug in “iCloud folder creation” or “Google Drive upload,” I know exactly which classes and methods to inspect first.

---

### 7. Step-by-step plan for you (Windsurf)

Please execute roughly in this order:

1. Scan the repo for:
   - Existing Google Drive integration classes, interfaces, and settings.
   - The current UI for choosing sync / storage targets.
   - Any existing abstractions around cloud storage.
2. Propose (in comments or very short notes) a minimal design for:
   - An iCloud storage backend implementing the existing abstraction.
   - How the new backend plugs into the existing sync flow.
3. Implement the iCloud backend:
   - Add platform-specific code only where necessary.
   - Ensure the `NextChord` folder is visible at the root of iCloud Drive in the Files app.
4. Wire it into the settings / sync UI:
   - Add the iCloud option.
   - Gate it to Apple platforms.
5. Add `myDebug`-based logging at the critical points described above.
6. Update or add tests where practical.
7. **Create the developer-facing documentation** described in section 6, capturing all components and how they interact (entry points, services, backends, UI flows, and debug hooks).
8. Run `flutter analyze` and resolve all issues introduced by these changes.
9. Leave the repo in a clean, compiling state, clearly indicating in comments where iCloud support lives and how it parallels Google Drive.

Remember: **Reuse as much existing code and structure as possible**, change only what’s necessary, and follow my existing **Best Practices** and **Debugging** rules in Cascade throughout the entire implementation.
