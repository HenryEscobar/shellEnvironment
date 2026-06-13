---
name: investigate
description: Start a structured investigation for a bug, crash, or architectural decision. Creates the dated directory, template file, and guides the debugging workflow.
disable-model-invocation: true
argument-hint: "<short description of what you're investigating>"
---

Start a structured investigation for: **$ARGUMENTS**

## Step 1: Create the investigation file

```bash
DATE=$(date +%Y%m%d)
SLUG=$(echo "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
DIR="docs/investigations/${DATE}"
FILE="${DIR}/${SLUG}.md"
mkdir -p "$DIR"
```

Write the investigation file at that path using this template:

```markdown
# <Title derived from $ARGUMENTS>

**Date:** <today's date YYYY-MM-DD>
**Status:** Open

## Problem
<To be filled in after initial research>

## Root Cause
<To be filled in after diagnosis>

## Fix
<To be filled in after resolution>

## Lessons Learned
<To be filled in after fix is confirmed>
```

## Step 2: Research the problem

1. Read relevant code files to understand current behavior
2. Check git log for recent changes in the affected area: `git log --oneline -20 -- <relevant paths>`
3. If a Sentry MCP tool is available and an error/crash is mentioned, pull the stack trace and frequency
4. If there are past investigations, check `ls docs/investigations/` for related prior work

## Step 3: Document findings

Update the investigation file's **Problem** section with what you found. Include:
- What was observed (symptoms)
- Reproduction steps if applicable
- Affected files with line references

## Step 4: Diagnose

Identify the root cause. Update the **Root Cause** section. Then stop and present your findings:

```
**Investigation:** <title>
**File:** <path to investigation file>
**Root cause:** <one-line summary>
**Affected:** <files and line numbers>

Say "fix" to implement the fix, or keep investigating.
```

Do NOT implement a fix until the user says "fix". Investigation first, always.

## Step 5: After the fix (when user says "fix")

1. Implement the fix on a feature branch
2. Run tests to verify
3. Update the investigation file:
   - **Status:** Fixed
   - **Fix:** What was changed (with file paths and line references)
   - **Lessons Learned:** What to remember for next time
