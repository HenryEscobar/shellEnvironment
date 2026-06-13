# Day 2: Security

## Focus
Identify and fix security vulnerabilities — injection, auth gaps, secrets exposure, missing headers.

## What to Fix

### SQL Injection
- String interpolation/concatenation in SQL queries → parameterized queries
- Template literals building SQL → use query builder or prepared statements
- `${}` or `+` in SQL strings is almost always a vulnerability

### Hardcoded Secrets
- API keys, tokens, passwords in source code → move to environment variables
- Check `.env` files are in `.gitignore`
- Look in config files, test fixtures, and comments

### Auth Gaps
- Endpoints missing authentication middleware
- Missing authorization checks (user A accessing user B's data)
- Verify all data-mutating endpoints require auth

### Security Headers
- Check for helmet/security header middleware (Express, Fastify, etc.)
- CORS configuration — overly permissive `*` origins
- CSP headers if serving HTML

### Dangerous Patterns
- `eval()`, `Function()`, `new Function()`
- `dangerouslySetInnerHTML` without sanitization
- `child_process.exec` with user input
- Unvalidated redirects
- Missing input validation/sanitization on user input

### Dependency Audit
- Run `npm audit` / `pnpm audit` / `pip audit` / `cargo audit`
- Fix critical and high severity vulnerabilities
- Document any that can't be fixed (no patch available)

## How to Make Changes

1. **Fix critical vulnerabilities first** (SQL injection, auth bypass, secrets)
2. **Each fix should be minimal** — change only what's needed for security
3. **Add tests** for security fixes when feasible (e.g., test that parameterized queries work)
4. **Do not refactor** unrelated code — stay in scope
5. **Document unfixable issues** in the PR description under "Manual Follow-up"

## Commit Message Format
```
cabin(day-2): [specific security fix]
```

Examples:
- `cabin(day-2): parameterize SQL queries in contact service`
- `cabin(day-2): add auth middleware to unprotected endpoints`
