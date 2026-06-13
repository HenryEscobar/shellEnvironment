# Investigation Files

Investigation files document root cause analyses, debugging sessions, and architectural decisions. They are preserved in the project repo for future reference.

## Location

```
docs/investigations/<DATESTAMP>/investigation-reason.md
```

- **DATESTAMP**: `YYYYMMDD` format (e.g. `20260303`)
- **investigation-reason**: kebab-case description (e.g. `contacts-tap-navigation-broken`)

## When to Create

- Root cause analysis for a bug
- Debugging sessions with non-obvious findings
- Architectural decisions (especially "why we didn't do X")
- Crash investigations with device logs

## Template

```markdown
# Title

**Date:** YYYY-MM-DD
**Status:** Fixed / Decided against / Open

## Problem
What was observed.

## Root Cause
Why it happened.

## Fix
What was changed (with file paths and line references).

## Lessons Learned
What to remember for next time.
```

## Finding Past Investigations

List existing investigations with `ls docs/investigations/`.
