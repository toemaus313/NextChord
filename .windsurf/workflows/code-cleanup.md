---
description: Code Cleanup
auto_execution_mode: 1
---

> **Context**  
> I’m building a production Flutter/Dart app called **NextChord**. I’m not an experienced developer, so I rely on you to keep the codebase aligned with solid, modern Flutter/Dart best practices.  
>  
> I want you to act as a **senior Flutter engineer / codebase caretaker** and periodically “tune up” the code I’ve written or generated so far.  
>  
> Each time I paste this prompt, I will tell you the **scope** (a file, folder, or feature). Within that scope, your job is to refactor for **readability, maintainability, and idiomatic Flutter/Dart**, while preserving behavior.

---

### 1. Scope for this run

For this run, the scope is:

> **[I WILL FILL THIS IN EACH TIME, e.g.:  
> “lib/features/setlists/**” or  
> “the currently opened file” or  
> “all widgets related to the mobile sidebar”]**

Only refactor **within** this scope unless there is a small, obvious shared helper or file that must be adjusted to keep things compiling.

---

### 2. High-level goals

Within the given scope:

1. **Preserve behavior**
   - The app should behave identically from the user’s perspective.
   - Don’t change any business rules, sync logic, or feature workflows unless you’re fixing an obvious bug.

2. **Align with Flutter/Dart best practices**
   - Idiomatic Dart (null-safety, `final` where appropriate, const constructors, etc.).
   - Idiomatic Flutter composition (small widgets, clear responsibilities).

3. **Reduce code smells**, especially:
   - Huge files (> ~400–500 lines) doing too much.
   - “God widgets” or “God classes” that handle UI + logic + data.
   - Very long `build()` methods or methods that do too many things.
   - Duplicate or near-duplicate code.
   - Mixed concerns (UI mixed with business logic or data access).
   - Confusing naming / unclear separation of responsibilities.

4. **Make the code easier to understand and extend**
   - Logical structure.
   - Good names.
   - Clear separation between UI, state management, and data.

---

### 3. Refactoring rules & patterns to apply

When refactoring within the scope:

#### 3.1 Decomposition & structure

- Break up **large widgets** into smaller ones:
  - If a widget builds multiple distinct UI sections (header, body, footer, sidebar, etc.), extract each into its own widget or helper method.
  - Prefer **composition over inheritance**.

- Break up **large files**:
  - If a file is getting large or mixing concerns, split it into multiple files grouped by feature or responsibility (e.g., `setlist_screen.dart`, `setlist_header.dart`, `setlist_song_list.dart`).

- Keep **methods small and focused**:
  - Keep `build()` and other methods reasonably short and readable.
  - Use private helpers like `_buildHeader()`, `_buildSongList()`, etc., when that adds clarity.
  - If a helper grows too complex, consider extracting a widget instead.

#### 3.2 Separation of concerns

- Keep **UI code** focused on presentation:
  - Move business and sync logic into controllers/notifiers/blocs/services where appropriate (respecting the existing state management approach).
  - Keep widgets mostly about layout and interaction, not data access.

- Avoid **mixing responsibilities** in a single class:
  - If a class is doing too much (fetching data, transforming it, building UI), split it into separate classes/modules.

#### 3.3 Flutter/Dart idioms

- Make use of:
  - `const` constructors and widgets where possible to reduce rebuilds and improve clarity.
  - `final` for variables that don’t change after assignment.
  - Clear null-safety (`?` and `!`) with minimal use of `!`, only when truly safe.

- Clean up:
  - Dead code (unused methods, fields, imports).
  - Overly complex conditions if they can be expressed more simply.
  - Any obvious formatting/layout inconsistencies.

#### 3.4 Avoid risky changes without explicit instruction

- Don’t:
  - Introduce new major dependencies or remove existing ones.
  - Change public APIs in a way that would break other parts of the app **unless** you also update all usages within the scope and explain what you did.
  - Change platform configs, build scripts, CI/CD config, or store/retrieval logic for the database/cloud unless I explicitly ask.

---

### 4. Process to follow each time

#### Step 1 – Analyze and report

1. Scan the scope and **summarize the main code smells and issues** you see:
   - Large widgets/files.
   - Mixed UI/logic concerns.
   - Repeated code.
   - Non-idiomatic patterns.

2. Propose a **refactoring plan** in bullets:
   - “Extract X into its own widget.”
   - “Split this file into these pieces.”
   - “Move this logic into a notifier/service.”
   - “Rename these classes/methods for clarity.”

   Keep this short and clear so I can understand what’s changing.

---

#### Step 2 – Apply refactors with diffs

Then implement the plan. For each group of changes:

1. Show the **code changes as diffs** (or clearly marked before/after).
2. Briefly explain what you did and why in **simple terms**:
   - No heavy jargon; explain like I’m a junior dev.
   - Example: “I split this 300-line widget into a parent + 3 child widgets, so it’s easier to read and reuse.”

Make sure the code still compiles logically and that behavior is preserved.

---

#### Step 3 – Final checklist

After refactoring:

1. Confirm you’ve checked:
   - No functionality changes from the user’s point of view (unless explicitly required to fix bugs).
   - No breaking API changes within the app unless all usages were updated.
   - Desktop/tablet vs mobile responsive layouts still follow the original intent (don’t undo previous responsive work).

2. Give me a short **summary**:
   - The main smells you removed.
   - The main structural improvements.
   - Any trade-offs or things I should be aware of for future work.

---

### 5. Important: Assume I will reuse this prompt

Assume I will paste this exact prompt regularly as a “Best Practices Alignment Procedure” for different parts of the codebase.

So for each run:

- **Respect the specified scope** I give you.
- Apply the same philosophy and constraints every time.
- Don’t undo previous refactors that improved structure, unless you’re clearly improving on them.

---

Now, please start by:
1. Analyzing the specified scope,  
2. Listing the key smells you notice, and  
3. Proposing a clear refactor plan before changing any code.