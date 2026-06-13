# Day 7: DevOps

## Focus
CI/CD completeness, deployment safety, smoke tests, environment management, monitoring.

## What to Check and Fix

### CI Pipeline Completeness
- Check for missing steps: lint, typecheck, test, coverage threshold, build
- Ensure CI fails on: test failures, lint errors, coverage below threshold
- Check that CI runs on PRs, not just pushes to main
- Add missing steps that are safe to add

### Smoke Tests
- Check if deployment has post-deploy verification
- Add a basic smoke test script that hits health/status endpoints
- Ensure critical paths are verified after deploy

### Deployment Safety
- Check for deployment scripts — do they have rollback capability?
- Verify environment variable management (no secrets in code, proper .env templates)
- Check Dockerfile/build configs for security (non-root user, minimal base image, .dockerignore)

### Environment Variable Management
- `.env.example` or `ENV_TEMPLATE.txt` exists and is up to date
- All required env vars are documented
- No env vars referenced in code but missing from templates
- Sensitive vars are properly excluded from version control

### Monitoring & Observability
- Check for error tracking (Sentry, etc.) — is it configured?
- Check for structured logging (not just `console.log`)
- Health check endpoints exist and return useful info
- Check for alerting on failures

### Git Hooks
- Pre-commit hooks configured (lint-staged, prettier, etc.)
- Check if hooks can be bypassed unintentionally

## How to Make Changes

1. **Start with CI gaps** — these protect everything else
2. **Add smoke tests** as simple scripts or CI steps
3. **Update env templates** to match actual usage
4. **Add monitoring config** only if the project uses a monitoring service
5. **Test CI changes locally** if possible before committing
6. **Do not change deployment infrastructure** — only improve safety checks around it

## Commit Message Format
```
cabin(day-7): [specific devops improvement]
```

Examples:
- `cabin(day-7): add typecheck and coverage threshold to CI pipeline`
- `cabin(day-7): add post-deploy smoke test script`
