---
name: test
description: Run the project's test suite and summarize results, failures, and coverage against the target. Stack-agnostic — projects may override with their own /test skill.
argument-hint: "[all | file/path | pattern]"
---

Run the project's tests and report results. This is the generic fallback. **If the
current project ships its own `/test` skill, that one wins** — only use this when the
project hasn't defined one.

## 1. Detect the toolchain

Look in the project root (and the relevant workspace package) for build/config files:

- `package.json` → read its `scripts` and `devDependencies` to find the runner
  (`jest`, `vitest`, `mocha`, `node --test`) and the package manager (`pnpm`/`npm`/`yarn`
  — check for `pnpm-lock.yaml` / `package-lock.json` / `yarn.lock`).
- `pom.xml` / `build.gradle` → Java: `mvn test` / `./gradlew test`.
- `pyproject.toml` / `setup.py` / `tox.ini` → Python: `pytest` (prefer if present), else `unittest`.
- `Cargo.toml` → Rust: `cargo test`. `go.mod` → Go: `go test ./...`.
- A `Makefile` with a `test` target → prefer `make test` if it exists.

If it's a monorepo with workspaces, scope to the package the argument points at; default
to the whole repo only when asked for `all`.

## 2. Run

- No argument → run the full suite with coverage if the runner supports it cheaply
  (e.g. `jest --coverage`, `vitest run --coverage`, `pytest --cov`).
- A file path or pattern argument → run just that target (e.g. `jest path/to/file.test.ts`,
  `pytest path/to/test_x.py -k pattern`).
- Use the project's own script when one exists (`pnpm test`, `npm test`) rather than
  invoking the runner directly — it picks up project config.

## 3. Summarize

Report, in this order:

1. **Totals** — passed / failed / skipped, and wall-clock time.
2. **Failures** — for each, the test name and a `file:line` reference, plus the one-line
   reason (assertion diff or error message). Don't paste the full stack unless asked.
3. **Coverage** — statement (and branch, if reported) vs the project's target. Default
   target is **80%** unless the project's CLAUDE.md / config says otherwise.
   - Below target: list the top ~5 lowest-coverage files **that were recently modified**
     (`git log --oneline -5` to find recently-touched files), since those are the
     actionable gaps.
   - At/above target: note it in one line and move on.
4. **Suggested next step** — for failures, the most likely fix; for coverage gaps, which
   behavior is untested. Keep it short.

Do not edit code or "fix" failing tests unless the user asks — running and reporting is
the job here.
