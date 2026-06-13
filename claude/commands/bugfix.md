---
name: bugfix
description: Set up a bug-fixing session with the correct workflow, Sentry context, and documentation habits
argument-hint: "[area or feature to focus on]"
---

## Bug Fix Session Setup

You are entering a structured bug-fixing session focused on `$ARGUMENTS` (or the whole project if no argument given).

### Your role in this session

You are a **receiver**, not a hunter. The user will report bugs — by describing them, pasting screenshots, or sharing Sentry links. Your job is to understand, document, and fix them one at a time in the correct order.

**Do NOT proactively scan for bugs or go looking for issues.** Wait for the user to surface them.

### Workflow (non-negotiable)

```
1. WAIT        →  User reports a bug (description, screenshot, Sentry link, etc.)
2. UNDERSTAND  →  Read relevant code, check Sentry if a link/ID is given, reproduce mentally
3. DOCUMENT    →  Add to TODO.md under ### Bugs before any code changes
4. CONFIRM     →  Tell the user what you found and what you plan to do. Stop.
5. PLAN        →  Only when the user says "plan" — enter plan mode, design the approach
6. FIX         →  Only after the user approves the plan — implement on a feature branch
```

**Never skip to step 5 or 6 without the user explicitly asking.** Document first, always.

### When a bug is reported

1. **Read the relevant files** for the affected area — understand the current behavior before diagnosing
2. **Check Sentry** if a Sentry MCP tool is available and an event ID or error name is given
   - Pull: error frequency, affected users, stack trace, first/last seen
3. **Document it** in `TODO.md` under `### Bugs`:
   ```
   - [ ] **[Area]: Short description** — What happens, when it happens, reproduction steps.
     Sentry ID if available. file:line reference.
   ```
4. **Report back** in this format, then stop:

   ```
   **Bug documented:** [short name]
   - Root cause: [what's wrong and where]
   - File: path/to/file:line
   - Impact: [who's affected, how often]

   Say "plan" to design the fix, or report the next bug.
   ```

### When the user says "plan"

Enter plan mode (use EnterPlanMode). Explore the code, design the approach, consider edge cases, present the plan for approval. Do not write code until the plan is approved.

### When the plan is approved — branching

```bash
git checkout main && git pull
git checkout -b fix/descriptive-name
```

All fixes on a branch. Never commit directly to main.

### Project context

If the project has a `CLAUDE.md` or `.claude/rules/`, read it before diagnosing. Things
that commonly turn an innocent-looking fix into a regression — check whichever apply:

- Data-layer rules (e.g. offline-first: local-store-first reads, a write/mutation queue) —
  a fix that writes straight to state or the network can break sync.
- Product/copy philosophy that constrains user-facing text.
- Which environment the data lives in (prod DB location, feature flags) so you debug
  against the right source.
- Any sync or data-consistency invariants a fix could silently violate.
