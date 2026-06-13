# Day 11: Dependency Cleanup

## Focus
Unused packages, outdated major versions, duplicate dependencies, license audit, bundle impact.

## What to Check and Fix

### Unused Packages
- Dependencies in package.json/pyproject.toml that are never imported in source code
- DevDependencies that are no longer referenced in scripts, configs, or test files
- Remove with confidence — package manager will error if something actually needs them
- Run tests after removing to verify

### Outdated Major Versions
- Run `npm outdated` / `pnpm outdated` to find outdated packages
- Focus on **major version** updates (breaking changes)
- Update one at a time, run tests between each
- Skip if changelog shows breaking changes that would require significant code changes — note in "Manual Follow-up"

### Duplicate Dependencies
- Different versions of the same package in the dependency tree
- Check with `npm ls <package>` or `pnpm why <package>`
- Resolve by aligning versions or using resolutions/overrides

### License Audit
- Check for copyleft licenses (GPL, AGPL) in dependencies if the project is proprietary
- Flag any problematic licenses in the PR description
- Don't remove packages just for licensing — flag for legal review

### Bundle Impact (Frontend)
- Large dependencies that could be replaced with smaller alternatives
- `moment` → `date-fns` or `dayjs` (only suggest, don't execute large replacements)
- Full lodash import → individual function imports
- Flag but don't replace if the change is large — note in "Manual Follow-up"

### Lock File Health
- Ensure lock file is committed and up to date
- Run `pnpm install --frozen-lockfile` (or equivalent) to verify consistency
- If lock file has conflicts or corruption, regenerate it

## How to Make Changes

1. **Remove unused packages first** — zero risk if tests pass
2. **Update patch/minor versions** — usually safe, run tests
3. **Update major versions one at a time** — read changelogs, run tests between each
4. **Do not replace packages** with alternatives (too risky for automated changes)
5. **Run the full test suite** after all changes
6. **List all removed/updated packages** in the PR description

## Commit Message Format
```
cabin(day-11): [specific cleanup action]
```

Examples:
- `cabin(day-11): remove 8 unused dependencies`
- `cabin(day-11): update minor versions and resolve duplicate lodash`
