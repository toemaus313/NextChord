---
description: Debug Cleanup - Iterative loop
auto_execution_mode: 1
---

You are an expert Flutter/Dart engineer working in my NextChord app. I want you to perform a one-time, thorough cleanup of ALL debugging code in this repo and leave the project in a clean, compiling state.

This is an **iterative loop task**: you must keep running analysis and fixing errors until **no analyzer errors remain**, and then perform a final analysis AFTER a short delay.

### High-Level Goal

- Remove **all debugging / troubleshooting code** that was added during development.
- Fix **all resulting compilation and analysis errors** so the project builds cleanly again.
- Do **not** change real app behavior, business logic, or UI beyond what is strictly necessary to remove debug noise.
- Respect my preference: **do not run `flutter run` automatically**, but you MAY run other Flutter/Dart commands (see below).
- Treat analyzer errors as **tasks to fix**, not as reasons to stop the workflow.

I want this to be a **complete cleanup pass**, not partial.

---

### 0. Error-Fix Loop (VERY IMPORTANT)

You must treat the error fixing as a loop and **not stop while any analyzer errors remain**.

Your loop is:

1. Run:
   - `flutter analyze`  
     (you may additionally use `flutter analyze | grep "error"` to highlight lines, but the primary success condition is that `flutter analyze` reports **no errors**.)
2. If there are any errors:
   - Parse the errors.
   - Modify the code to fix them.
   - Go back to step 1.
3. Only when `flutter analyze` reports **zero errors**:
   - Exit the loop.
   - Then perform a **stabilization delay** (see Final Clean State below) and rerun analysis one last time before you stop and summarize.

**Do not** stop the Cascade workflow after the first round of errors.  
**Do not** ask me to rerun the command manually.  
Keep iterating yourself until `flutter analyze` is clean and the final delayed analysis also shows no errors.

---

### 1. Scope

- Apply this cleanup to the **entire Flutter/Dart codebase** in this repo (typically `lib/`, `test/`, and any other Dart code).
- Also consider the root-level `debugs_active.md` file if it exists.

---

### 2. What counts as “debugging code” to remove

Search for and remove **all** of the following kinds of debug-related artifacts (non-exhaustive list; use your judgment):

- Print/log statements:
  - `print(...)`
  - `debugPrint(...)`
  - `log(...)` from `dart:developer`
  - Any logging calls clearly added for debugging, e.g. `logger.d(...)`, `logger.i(...)`, `logger.e(...)` if they are not part of a deliberate, structured logging system.

- Debug-only flags or code blocks:
  - `if (kDebugMode) { ... }` blocks that only contain logging or temporary UI.
  - Temporary boolean flags like `bool debugSomething = true;` or similar used only for troubleshooting.

- Temporary UI for debugging:
  - Buttons, menu items, widgets, or extra text that are clearly labeled as debug/test (e.g. “Debug”, “Test Sync”, “Print State”, etc.) and were not meant to be part of the production UX.
  - Extra overlay widgets, banners, or console output features explicitly marked as debug.

- Any items listed in `debugs_active.md`:
  - Use `debugs_active.md` (if present) as a checklist of known debug entries.
  - For each entry, remove the described debug code and then update or clear `debugs_active.md` accordingly.

When in doubt, prefer to remove noisy debugging code. If something looks like **real application logging** (intentional, structured logging that should stay), leave it.

---

### 3. How to remove debugs **safely** (no broken build)

When removing debugging code, be careful not to break control flow or leave invalid syntax:

- If a line like `if (kDebugMode) print(...);` exists, delete the entire line (or the whole `if` block) rather than leaving an empty `if`.
- If an `if/else` or `switch` branch contains only debug code:
  - Either remove the entire branch if it’s clearly meaningless without the debug, or
  - Replace it with an empty comment or safe no-op if needed to keep logic valid.
- If a variable, parameter, or import was only used for debugging:
  - Remove the now-unused variable/parameter, and clean up any unused imports.
- Do **not** accidentally remove non-debug logic that the app actually depends on (e.g. real error handling, user messages, or state changes).

If you’re unsure whether something is debug-only or real logic, **err on the side of keeping it** and explain it in your final summary.

---

### 4. Commands you may run

To keep the code compiling and clean, you are allowed (and encouraged) to run:

- `flutter analyze`
- Optionally `flutter analyze | grep "error"` to highlight errors, but the success condition is that `flutter analyze` reports **no errors**.
- `flutter test`
- `flutter pub get`
- `flutter pub run build_runner build` (or watch) if needed for generated code

You must **NOT** run `flutter run` automatically. I will run the app myself.

---

### 5. Process to follow

#### Step 1 – Inventory & Plan

1. Scan the codebase for debug patterns and `debugs_active.md` (if present).
2. List the main categories of debug code you find (e.g., log statements, debug buttons, experimental views, etc.).
3. Propose a short cleanup plan, for example:
   - “Remove all print/debugPrint/log calls.”
   - “Remove debug-only buttons and test UI in X, Y, Z screens.”
   - “Clean up unused imports and variables that were only used for logging.”
   - “Use debugs_active.md as a checklist and clear it afterward.”

#### Step 2 – Systematic Removal + Error-Fix Loop

For each category in the plan:

1. Remove the debug code carefully, file by file.
2. After a logical batch of changes, **enter the error-fix loop**:
   - Run `flutter analyze`.
   - If any errors are reported:
     - Fix **all** resulting errors and warnings that would prevent compilation or indicate broken references:
       - Add or remove imports as needed.
       - Remove unused variables/parameters created by the deletion of debug code.
       - Fix any control-flow or syntax errors caused by removing lines.
     - Then **run `flutter analyze` again**.
     - Repeat this process until `flutter analyze` reports **no errors** for that batch.
3. Optionally, for visibility, you may run `flutter analyze | grep "error"` after each clean `flutter analyze` run to show that there are no error lines.
4. If `debugs_active.md` exists:
   - For each entry, confirm the corresponding debug code is removed.
   - Remove or update that entry so the file reflects the current (clean) state.

---

### 6. Final Clean State with Stabilization Delay

After **all** debugs are removed and the error-fix loop has produced a clean `flutter analyze`:

1. **Insert a short delay before the final analysis** to avoid race conditions:
   - On Unix-like shells: run something like  
     `sleep 10 && flutter analyze`
   - Or on PowerShell (Windows):  
     `powershell -Command "Start-Sleep -Seconds 10; flutter analyze"`
   - You may then optionally pipe to `grep "error"` if helpful for readability:  
     `sleep 10 && flutter analyze | grep "error"`  
     or the PowerShell equivalent.
2. Confirm that this **final delayed `flutter analyze`** run reports **no errors**.
   - Warnings are okay, but there should be **no analyzer errors**.
3. Optionally run `flutter test` and ensure tests still pass (if tests exist).
4. Make sure `debugs_active.md` is either:
   - Empty,
   - Or clearly updated to reflect that there are no active debug hooks.

Do not end the workflow until this final delayed analysis has been run and verified clean.

---

### 7. What NOT to change

During this cleanup:

- Do **not** change business logic (data transformations, sync decisions, etc.) beyond what is strictly necessary to remove debug code and fix errors.
- Do **not** change UI flows or navigation behavior.
- Do **not** modify platform-specific config (iOS/Android/desktop) unless required to fix a direct compilation error introduced by this process.
- Do **not** introduce new features or architectural changes. This task is strictly about removing debugs and restoring a clean, compiling state.

---

### 8. Deliverables

At the end of this workflow, provide:

1. A short summary of:
   - Which types of debug code you removed.
   - Any tricky cases where you had to keep something that looked debug-like.
2. Confirmation that:
   - A final **delayed** `flutter analyze` run (with the 10 second pause) completes **without errors**.
   - Any test suite you ran (`flutter test`) passes.
   - `debugs_active.md` is up to date and does not list stale debug entries.

Now, please begin by scanning the repo, outlining your cleanup plan, and then systematically removing all debugging code. **Keep iterating in the error-fix loop until `flutter analyze` and the final delayed analysis both report zero errors before you stop and summarize.**