---
trigger: always_on
---

# Cascade Rule: Standardized Debug Logging Pattern & Safe Cleanup

## Rule Purpose
Ensure all debugging in this project uses a single standardized method (myDebug), prevent the introduction of unstructured debug statements, and allow Windsurf Cascade to safely remove all debugging code without leaving syntax errors.

---

## Rule: Enforce Standard Debug Function

### Developer Intent
- All debugging logs must use a single wrapper function: main.myDebug().
- No direct use of print(), debugPrint(), log(), or ad-hoc logs.
- Debug output must be globally toggleable.
- Removing debug statements must never break syntax.

### Implementation Requirements
When Cascade generates or modifies code:

1. Always define the global debug flag and helper:

       bool isDebug = true;

       void myDebug(String message) {
         if (isDebug) {
           debugPrint(message);
         }
       }

2. All debug logs must use:

       main.myDebug("Your message");

3. Cascade must never produce:
   - print("...")
   - debugPrint("...")
   - logger.log(...)
   - myDebug() - always use the main.myDebug instead
   - temporary debug-only variables
   - inline debug expressions or trailing expressions
   - logs placed inside unrelated function calls

4. Debug statements must always be placed on separate lines.

---

## Rule: Debug Cleanup Safety

When the user instructs Cascade to remove debug statements:

Cascade must:

1. Check debug_exceptions.md for items not to be touched, then delete only entire lines containing main.myDebug(...). 
2. Run flutter analyze.
3. Fix all syntax errors.
4. Re-run flutter analyze.
5. Repeat until zero errors remain.

Cascade must not:
- Partially delete a main.myDebug() call
- Remove surrounding logic, punctuation, or arguments
- Leave dangling commas, parentheses, or empty blocks

---

## Rule: Debug Toggle Behavior

Cascade must preserve the global toggle:

- isDebug = true → debug output enabled
- isDebug = false → debug output suppressed

Cascade must not remove this toggle unless explicitly commanded.

---

## Rule: Blocking Undesired Debug Patterns

Cascade must automatically rewrite any of the following into main.myDebug():

- print()
- debugPrint()
- log()
- myDebug()
- inline logging expressions
- commented-out debug lines

Example rewrite:

       main.myDebug("...");

Unless the user explicitly requests an exception.

---

## Rule: Project-Wide Enforcement

Cascade must apply this rule consistently across:

- lib/
- test/
- widgets
- services
- data models
- business logic
- any file created or modified by Cascade

This ensures predictable cleanup and stable behavior across the entire project.

---