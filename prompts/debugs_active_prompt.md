```markdown
You are working in my Flutter/Dart app repo (NextChord). We have a global debugging helper called `myDebug()` defined in `main.dart`. All debugs in the codebase are supposed to go through this helper or thin wrappers around it.

We already have a file called `debugs_active.md` in the repo that tracks where debugs are currently active, but the format is not ideal. I want you to normalize and update that file so it becomes a super-simple “quick undo” list that an LLM or script can use later to remove debugs quickly and safely.

In addition, I want you to support **two styles** of debug tracking:
1. Simple line-based tracking for normal `myDebug()` calls.
2. Block-based tracking for **debug-only blocks** (like try/catch blocks whose only purpose is debugging), clearly marked in the code.

---

## High-Level Goal

1. **Scan the repo** for all active debugs that use `myDebug()` (including any thin wrapper functions around it).
2. **Normalize and rebuild `debugs_active.md` from scratch** using a simple, rigid format.
3. **Introduce and use debug-only block markers** for blocks that exist purely to support debug logging, and track those as full ranges.
4. Ensure the tracking is simple enough that a later pass (by AI or script) can:
   - Remove individual debug calls, or
   - Remove entire debug-only blocks, using `debugs_active.md` plus the markers in code.

---

## File Format for `debugs_active.md`

Replace the contents of `debugs_active.md` with:

- A small heading at the top, for example:

  ```markdown
  # Active debug locations
  ```

- A Markdown **numbered list**, where each list item corresponds to exactly one file that currently contains at least one active debug.

Each list item must follow this exact pattern:

```text
1. lib/screens/setlist_modal.dart (23-25, 40, 66-67)
2. lib/screens/viewer_screen.dart (23, 56, 66-67, 120-128)
3. lib/widgets/some_widget.dart (101)
```

Rules:

- Use **repo-relative paths**, starting from the repo root (e.g. `lib/screens/viewer_screen.dart`).
- Use a **single space** after the period, then the path, then a space, then the line numbers in parentheses.
- Inside the parentheses:
  - **Single lines**: `23`
  - **Ranges**: `23-25`
  - Multiple entries: `23, 56, 66-67` (comma+space separated)
- Within each file’s entry, line specs must be **sorted ascending**.
- Numbered list items (the files) must be sorted **alphabetically by path**.

---

## Two Kinds of Debug Tracking

We are explicitly supporting **both** of these:

### 1. Normal debug calls (`myDebug()` inside existing logic)

For “normal” debug usage:

- The code already has a `try`/`catch` or normal block that exists for real logic.
- We simply add `myDebug()` calls inside that structure.

**For these**, in `debugs_active.md`:

- Treat the “debug line” as the line where `myDebug(...)` is called.
- If a given `myDebug()` call is a single-line call, record a **single line number**.
- If the call spans multiple lines (due to long parameters, multiline strings, etc.), record the **inclusive range** as `start-end`.

Example:

```dart
myDebug('Loading setlist $id');
```

If this is on line 42 → `42`.

```dart
myDebug(
  'Loading setlist',
  extra: {'id': id, 'user': currentUser.id},
);
```

If this spans lines 42–45 → `42-45`.

These entries are just line numbers or ranges that correspond to **the call itself**, with no special markers.

---

### 2. Debug-only blocks (new try/catch or similar, created just for debugging)

Sometimes we create a structure (like a new `try/catch`) **solely** so we can add debugging:

```dart
// DEBUG-ONLY-BLOCK START
try {
  await someAsyncOperation();
  myDebug('someAsyncOperation succeeded');
} catch (e, st) {
  myDebug('someAsyncOperation failed', error: e, stackTrace: st);
}
// DEBUG-ONLY-BLOCK END
```

This is a **debug-only block**.

For any such block:

1. **You MUST wrap it with marker comments:**
   - `// DEBUG-ONLY-BLOCK START`
   - `// DEBUG-ONLY-BLOCK END`

2. The block should contain only debug-related logic and/or safe no-op plumbing for debugging. It must be safe to remove entirely later.

3. In `debugs_active.md`, you must:
   - Record the **full line span** from the `// DEBUG-ONLY-BLOCK START` line through the `// DEBUG-ONLY-BLOCK END` line, as a range like `120-128`.
   - This is in addition to any simple `myDebug` line ranges, but you should avoid redundant overlapping ranges when possible. Prefer the **single block range** that covers all `myDebug()` calls in that block.

This allows a future cleanup pass to:

- Look up `120-128` in `debugs_active.md`,
- Confirm the range is bounded by `DEBUG-ONLY-BLOCK START/END`,
- Safely remove the whole block.

---

## What to Do With Existing Code

When scanning existing code:

1. Search for `myDebug(` across the repo.

2. For each occurrence, decide whether it’s:

   - **Type A: Normal debug call** inside preexisting logic (most common case), or
   - **Type B: A block that appears to exist only to support debugging** (e.g., a `try/catch` that only logs via `myDebug` and otherwise does not alter real behavior).

3. For Type A:
   - Treat as a normal debug call: record only the call line or range in `debugs_active.md`.

4. For Type B (a clear debug-only block):
   - Wrap the block with `// DEBUG-ONLY-BLOCK START` and `// DEBUG-ONLY-BLOCK END` comments if they are not there already.
   - Record the full span from the START line to the END line in `debugs_active.md` as a range.

   Be conservative:
   - Only mark a block as debug-only if it truly can be removed entirely without breaking real app logic.
   - If in doubt, treat the `myDebug` calls inside as normal debug calls (Type A) and do **not** mark the whole block.

---

## Task Steps

Follow these steps now:

1. **Inspect `debugs_active.md`**
   - Open the file and understand the existing tracking format.
   - We are going to replace the content with the new format; you do not need to preserve the old structure beyond using it as a reference if useful.

2. **Scan for all debug usages**
   - Find all occurrences of `myDebug(` throughout the repo.
   - Include any thin wrappers that obviously just call `myDebug()` under the hood.

3. **Classify and, where appropriate, annotate blocks**
   - For each file, examine the surrounding context of `myDebug()` calls.
   - When a `try/catch` or other block clearly exists *only* for debugging:
     - Convert it into a debug-only block by adding:
       - `// DEBUG-ONLY-BLOCK START` above the block.
       - `// DEBUG-ONLY-BLOCK END` after the block.
     - Ensure the block contains only debug-related logic (no core behavior).
   - For all other cases, treat the calls as normal debugs (Type A).

4. **Construct the debug location data**
   - For each file with debugs:
     - Collect normal debug call lines as single numbers or ranges (`23`, `42-45`).
     - Collect debug-only block ranges using the `DEBUG-ONLY-BLOCK START/END` boundaries, e.g. `120-128`.
   - Sort all line specs for the file in ascending order.
   - Group them by file (one item per file).

5. **Rewrite `debugs_active.md`**
   - Clear the file contents.
   - Write the heading:

     ```markdown
     # Active debug locations
     ```

   - Below the heading, write the numbered list of files in **alphabetical order by path**, following the format described earlier.

6. **Validation / Sanity Checks**
   - Re-scan the repo for `myDebug(` and confirm:
     - Every file with a `myDebug()` call or debug-only block is represented in `debugs_active.md`.
     - No file without debugs appears in the list.
   - For any `DEBUG-ONLY-BLOCK START` / `END` pairs, ensure:
     - They fully enclose the intended block.
     - The line range for that block is included in `debugs_active.md`.

---

## Going Forward (for Future Work)

From now on, whenever you (as the AI) add, modify, or remove debugs:

- For normal `myDebug()` calls inside existing logic:
  - Add/remove/update the appropriate line numbers in `debugs_active.md`.

- For any new debug-only block:
  - Always wrap it with `// DEBUG-ONLY-BLOCK START` and `// DEBUG-ONLY-BLOCK END`.
  - Record the full line range of that block in `debugs_active.md`.

- When removing debugs:
  - If you remove a debug-only block that has the START/END markers, remove the entire block and delete its range from `debugs_active.md`.
  - If you remove a normal `myDebug()` call, update the relevant line number(s) or range(s) for that file in `debugs_active.md`.

Always maintain:

- Alphabetical ordering of files in `debugs_active.md`.
- Sorted line numbers/ranges within each file’s entry.
- Consistent formatting as defined above.

---

Now, please:

1. Perform the scan and classification of debugs (normal vs debug-only blocks).
2. Add `DEBUG-ONLY-BLOCK START/END` markers where appropriate.
3. Rebuild `debugs_active.md` using the new format and rules.
4. Show me the final contents of `debugs_active.md` in your response so I can review them.
```
