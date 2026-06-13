# Day 9: API Design

## Focus
REST conventions, response format consistency, error standardization, endpoint hygiene.

## What to Check and Fix

### REST Conventions
- Resource naming: plural nouns (`/contacts`, not `/contact` or `/getContacts`)
- HTTP methods: GET (read), POST (create), PUT/PATCH (update), DELETE (delete)
- Nested resources: `/contacts/:id/notes` not `/getContactNotes`
- No verbs in URLs: `/contacts` + POST, not `/createContact`

### Response Format Consistency
- All endpoints should return the same envelope structure
- Check: do some return `{ data: ... }` while others return raw arrays?
- Standardize on the project's most common pattern
- Pagination responses should include total count, page info

### Error Response Standardization
- All errors should have the same shape: `{ error: { message, code, status } }` or similar
- HTTP status codes should be correct (400 for validation, 401 for auth, 404 for not found, etc.)
- No 200 responses with error bodies
- No stack traces in production error responses

### Missing Endpoints
- CRUD completeness: if there's a GET and POST, is there PUT and DELETE?
- Only add missing endpoints if they're clearly needed (referenced in frontend but returning 404)

### Redundant Endpoints
- Multiple endpoints doing the same thing
- Overly specific endpoints that should be query parameters
- Flag but don't remove without clear evidence they're unused

### Input Validation
- All endpoints should validate request body/params
- Missing validation → add it using the project's existing validation approach
- Consistent error messages for validation failures

## How to Make Changes

1. **Fix response format inconsistencies first** — most visible to consumers
2. **Standardize error responses** — consistent shape and status codes
3. **Fix naming convention violations** — but be cautious with breaking changes
4. **Add missing validation** — prevent bad data from entering the system
5. **Run tests after each change** — API changes can break integration tests
6. **Note breaking changes** in the PR description — anything that changes response shape or endpoint paths

## Commit Message Format
```
cabin(day-9): [specific API improvement]
```

Examples:
- `cabin(day-9): standardize error response format across endpoints`
- `cabin(day-9): add input validation to contact and category endpoints`
