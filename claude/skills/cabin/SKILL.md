---
name: cabin
description: '"Week locked in a cabin" intensive improvement session — diagnoses codebase issues and executes parallel improvement workstreams, each as its own PR'
argument-hint: "[diagnose | run <day-numbers> | run all]"
disable-model-invocation: true
---

# /cabin — Intensive Codebase Improvement Session

You are running the `/cabin` skill — an intensive codebase improvement session that diagnoses issues and executes parallel improvement workstreams, each producing its own PR.

## Argument Parsing

Parse the user's argument:

- **No argument** or **`diagnose`** → Run Phase 1 (Diagnostic)
- **`run <numbers>`** (e.g., `run 3`, `run 1 2 5`) → Run Phase 2 for those workstreams
- **`run all`** → Run Phase 2 for all workstreams the itinerary rated HIGH or MEDIUM

If the user says `run` but no itinerary exists yet, tell them to run `/cabin diagnose` first.

## The 11 Default Workstreams

| Day | Name                 | File                      |
| --- | -------------------- | ------------------------- |
| 1   | Architecture         | workstreams/architecture.md |
| 2   | Security             | workstreams/security.md     |
| 3   | Testing              | workstreams/testing.md      |
| 4   | Code Quality         | workstreams/code-quality.md |
| 5   | UX Copy              | workstreams/ux-copy.md      |
| 6   | Performance          | workstreams/performance.md  |
| 7   | DevOps               | workstreams/devops.md       |
| 8   | Documentation        | workstreams/documentation.md |
| 9   | API Design           | workstreams/api-design.md   |
| 10  | Accessibility        | workstreams/accessibility.md |
| 11  | Dependency Cleanup   | workstreams/dependency-cleanup.md |

---

## Phase 1: Diagnostic (`/cabin diagnose`)

Launch a **single Explore agent** (subagent_type: "Explore", thoroughness: "very thorough") to read the codebase and produce an itinerary.

### Diagnostic Agent Prompt

Tell the agent:

> You are diagnosing a codebase for an intensive improvement session. Your job is to assess 11 workstreams and produce a structured itinerary. Do NOT make any changes — research only.
>
> **Read these first:**
> - CLAUDE.md and any .claude/rules/ files (project behavioral rules)
> - package.json / pyproject.toml / Cargo.toml / go.mod / requirements.txt (detect stack)
> - Directory structure (`ls` top-level, then key subdirectories)
> - Large files (>500 lines) — God Object candidates
> - `git log --oneline -20` — recent velocity & focus areas
>
> **Then investigate each workstream:**
>
> 1. **Architecture** — Find files >500 LOC. Check for SRP violations, God Objects, inconsistent DI patterns, dead code, duplication between files.
> 2. **Security** — Grep for SQL string interpolation, hardcoded secrets/API keys, missing auth middleware, `eval()`, `dangerouslySetInnerHTML`, missing security headers. Run `npm audit` / `pip audit` if applicable.
> 3. **Testing** — Run the test suite and capture coverage output. Identify files/modules with 0% or low coverage. Note the project's coverage target.
> 4. **Code Quality** — Find methods >20 lines, classes with 5+ constructor params/dependencies, boolean function parameters, repeated parameter groups (data clumps).
> 5. **UX Copy** — Find all user-facing strings (UI text, error messages, notifications, empty states). Check for consistency, tone, and compliance with any product philosophy in CLAUDE.md.
> 6. **Performance** — Look for N+1 query patterns (loops with DB calls), missing DB indexes, unbounded queries (no LIMIT/pagination), synchronous blocking in async code, large bundle imports.
> 7. **DevOps** — Check CI config (.github/workflows/, .gitlab-ci.yml, etc.), Dockerfile, deployment scripts. Look for missing steps (lint, typecheck, coverage threshold, smoke tests).
> 8. **Documentation** — Check README completeness, missing JSDoc/docstrings on public interfaces, undocumented API endpoints, complex logic without inline comments.
> 9. **API Design** — Check REST conventions (naming, HTTP methods, status codes), response format consistency, error response standardization, missing or redundant endpoints.
> 10. **Accessibility** — If there's a UI: check for missing ARIA labels, alt text, color contrast issues, keyboard navigation, focus management. If no UI: mark SKIP.
> 11. **Dependency Cleanup** — Check for unused packages (imports that don't match any `package.json` dep), outdated major versions, duplicate dependencies, large transitive deps.
>
> **Output format — write this as a Markdown file:**
>
> ```markdown
> # Cabin Itinerary — [Project Name]
>
> **Date:** YYYY-MM-DD HH:mm
> **Stack:** [detected stack]
> **Size:** [file count, LOC estimate]
> **Test coverage:** [current %]
>
> ## Project Rules
> [Summarize any CLAUDE.md / .claude/rules/ constraints that workstreams must respect]
>
> ## Workstream Assessment
>
> ### Day N: [Name] — [HIGH | MEDIUM | LOW | SKIP]
> **Findings:**
> - [specific finding with file:line reference]
> - [specific finding with file:line reference]
>
> **Scope:** [estimated number of files to touch, rough description]
>
> [Repeat for all 11]
>
> ## Ad-Hoc Workstreams
> [If project-specific gaps exist beyond the 11 defaults, recommend them here with the same format. E.g., "Day 12: Offline Sync Audit" for projects with mutation queues.]
>
> ## Recommended Run Order
> [List day numbers in priority order, grouping by severity]
> ```

### After the Diagnostic Agent Returns

1. Determine the output directory: `docs/cabin/YYYY-MM-DD-HHmm/` (use current date/time)
2. Create the directory and write the itinerary to `docs/cabin/YYYY-MM-DD-HHmm/itinerary.md`
3. Display a summary to the user: workstream names, severities, and recommended run order
4. Tell the user: "Run `/cabin run <numbers>` to execute specific workstreams, or `/cabin run all` for all HIGH+MEDIUM."

---

## Phase 2: Execute (`/cabin run <numbers>`)

### Prerequisites

1. Find the most recent itinerary: look in `docs/cabin/` for the latest `YYYY-MM-DD-HHmm/itinerary.md`
2. Read the itinerary
3. Read each requested workstream's instruction file from the skill directory (`~/.claude/skills/cabin/workstreams/<name>.md`)

### Resolve "run all"

If the user said `run all`, read the itinerary and select all workstreams rated HIGH or MEDIUM.

### Spawn Workstream Agents

For each selected workstream, launch an Agent with **`isolation: "worktree"`** in a **single message** (all agents spawn concurrently).

Each agent's prompt must include:

1. **The full itinerary** (pasted into the prompt so the agent has codebase context)
2. **The workstream instructions** (from `workstreams/<name>.md`)
3. **These execution instructions:**

> You are executing workstream Day [N]: [Name] for a cabin intensive session.
>
> **Context:** The itinerary below describes the codebase and your specific findings. Use it — do NOT re-read the entire codebase.
>
> **Your task:**
> 1. Create branch `cabin/[N]-[name]` from main (e.g., `cabin/3-testing`)
> 2. Make the changes described in your workstream instructions, focusing on the findings from the itinerary
> 3. Run tests after your changes to make sure nothing breaks (`pnpm test` or equivalent — check CLAUDE.md for the test command)
> 4. Commit your changes with a descriptive message: `cabin(day-[N]): [summary of changes]`
> 5. Push the branch and create a PR using `gh pr create` with this format:
>
> ```
> Title: cabin(day-[N]): [workstream name] improvements
> Body:
> ## Summary
> [2-3 bullet points of what was done]
>
> ## Findings Addressed
> [List specific findings from the itinerary that were fixed, with file:line refs]
>
> ## Not Addressed (Manual Follow-up)
> [Any findings that were too risky or complex for automated fixes]
>
> ## Verification
> - [ ] Tests pass
> - [ ] No new lint errors
> - [ ] Changes reviewed for correctness
> ```
>
> 6. Write a workstream report to stdout summarizing: what you changed, PR link, what needs manual follow-up
>
> **Rules:**
> - Respect ALL project rules from CLAUDE.md and .claude/rules/
> - Do not make changes outside your workstream's scope
> - If tests fail after your changes, fix them or revert the breaking change
> - Prefer minimal, safe changes over ambitious refactors
> - NEVER include Co-Authored-By lines in commits
> - NEVER include AI attribution in PR descriptions

### After All Agents Complete

1. Collect all agent results
2. Write a summary to `docs/cabin/YYYY-MM-DD-HHmm/summary.md`:

```markdown
# Cabin Session Summary

**Date:** YYYY-MM-DD
**Workstreams executed:** [list]

## Results

### Day N: [Name]
- **PR:** [link]
- **Changes:** [brief summary]
- **Manual follow-up:** [items if any]

[Repeat for each workstream]

## Aggregate Stats
- Total PRs created: N
- Files changed: ~N
- Tests added: ~N (if applicable)
```

3. Display the summary to the user with PR links.

---

## Notes for the Orchestrator

- **Workstream files are in the skill directory**, not the project. Read them from `~/.claude/skills/cabin/workstreams/`.
- **The itinerary is in the project directory** at `docs/cabin/YYYY-MM-DD-HHmm/itinerary.md`.
- **Each agent runs in a worktree** — they get an isolated copy of the repo. The worktree is auto-cleaned if no changes are made.
- **Ad-hoc workstreams** recommended by the diagnostic don't have instruction files. For these, include the diagnostic's description and findings directly in the agent prompt and tell the agent to follow the same execution pattern as the defaults.
- **If a workstream was rated SKIP**, warn the user if they explicitly request it but still run it if they insist.
