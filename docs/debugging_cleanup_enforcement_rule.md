---
trigger: always_on
---

# Cascade Rule: Debug Cleanup Loop & Unsafe Debug Blocking

## Rule Purpose
Automate safe debug cleanup and strictly block unsafe or unstandardized debug statements across the project. This rule assumes the existence of a standardized debug helper:

    bool isDebug = true;

    void myDebug(String message) {
      if (isDebug) {
        debugPrint(message);
      }
    }

All new or existing debug output should use `myDebug` only.

---

## Rule: Automated Debug Cleanup Loop

When the user gives any instruction equivalent to:

- "remove all debug statements"
- "strip all debug logging"
- "clean up debugging"
- "remove myDebug calls"

Cascade must perform the following sequence:

1. **Targeted deletion only**
   - Remove *only* entire lines that contain `myDebug(`.
   - Do not remove or alter any other code surrounding those lines.
   - Do not modify the definition of `isDebug` or `myDebug` unless explicitly requested.

2. **Run static analysis**
   - Execute: `flutter analyze`.

3. **Fix all reported issues**
   - For each error reported by `flutter analyze`, Cascade must:
     - Fix the error in the minimal, safest way possible.
     - Prefer restoring missing punctuation, braces, or structure before refactoring logic.
     - Avoid changing function behavior except where strictly necessary to restore valid code.

4. **Re-run static analysis**
   - Execute `flutter analyze` again after each batch of fixes.

5. **Loop until clean**
   - Repeat steps 3–4 until `flutter analyze` reports **zero errors**.
   - Only then may Cascade consider the debug cleanup complete.

6. **Report back**
   - Summarize:
     - The number of `myDebug` lines removed.
     - Any non-trivial behavioral changes made to fix errors.
     - Confirmation that `flutter analyze` now passes with no errors.

---

## Rule: Strict Blocking of Unsafe Debug Patterns

To prevent future cleanup problems, Cascade must **block** and rewrite any unsafe or non-standard debug usage.

### Disallowed Debug Patterns

Cascade must never introduce or preserve the following patterns in new or edited code:

- `print("...")`
- `debugPrint("...")` (outside `myDebug`)
- `log("...")` or `logger.log(...)`
- Inline debugging such as:
  - `someFunction(debugPrint("..."))`
  - `if (kDebugMode) print("...");`
- Temporary variables used *only* for debugging.
- Trailing or chained logging expressions attached to primary logic.

### Automatic Rewrite Rule

When Cascade encounters any of the disallowed patterns above, it must:

1. Convert them to a standalone `myDebug` call on its own line, e.g.:

       myDebug("Original message or variable contents");

2. If logging variable values, make the variables explicit in the message, e.g.:

       myDebug("userId: $userId, songId: $songId");

3. Ensure the resulting statement does **not** alter the execution order or return values of existing expressions.

---

## Rule: Consistency and Scope

Cascade must enforce this rule across the entire project:

- `lib/`
- `test/`
- Widgets
- Services
- Data models
- Business logic
- Any new files created by Cascade

No new debug pattern should be introduced that cannot be:

- Globally toggled via `isDebug`, and
- Safely removed later via the automated cleanup loop described above.

---

## Rule: Respect Explicit User Overrides

If the user explicitly requests a direct `print`/`debugPrint`/`log` (e.g., for teaching, examples, or external APIs), Cascade may comply **only if**:

- The code is clearly commented as an exception, and
- It is not part of the app's normal runtime debugging strategy.

Otherwise, Cascade must default to the standardized `myDebug` approach.
