# Day 5: UX Copy

## Focus
Audit all user-facing strings for tone, consistency, clarity, and compliance with the product's philosophy.

## What to Audit

### Product Philosophy Compliance
- Read CLAUDE.md for any behavioral rules about user-facing language
- Check for guilt-inducing language, shame, or negative framing
- Ensure copy aligns with the product's stated values and tone

### Terminology Consistency
- Same concept should use the same word everywhere
- Example: don't mix "contact" and "person" and "connection" for the same thing
- Build a mini glossary from what you find, standardize on one term per concept

### Error Messages
- Must be helpful, not cryptic — tell the user what to do, not what went wrong internally
- No technical jargon (no "500", "null", "undefined", "exception")
- No blame ("You entered an invalid..." → "Please enter a valid...")
- Actionable: include what the user can do next

### Empty States
- Every list/screen that can be empty needs a helpful empty state
- Should encourage action, not just state the obvious
- "No contacts yet" → "Add your first contact to get started"

### Notifications & Alerts
- Check push notification text, in-app alerts, toast messages
- Must be concise, clear, and match the product's tone
- No unnecessary urgency or anxiety-inducing language

### Labels & Buttons
- Button text should be verbs: "Save", "Delete", "Add Contact"
- Labels should be clear without context
- Avoid ambiguous text like "Submit", "OK", "Click here"

### Pluralization & Edge Cases
- "1 contacts" → "1 contact"
- "You have 0 new messages" — is this the right empty state?
- Check for proper handling of singular/plural

## How to Make Changes

1. **Grep for string patterns** — template literals, JSX text, i18n keys, notification bodies
2. **Fix copy in place** — edit the strings directly in source files
3. **Do NOT restructure code** — only change the string values
4. **List all changes in the PR** so they can be reviewed for product accuracy
5. **Flag ambiguous cases** in "Manual Follow-up" — some copy decisions need product input

## Commit Message Format
```
cabin(day-5): [copy improvement summary]
```

Examples:
- `cabin(day-5): fix guilt-inducing language in notification copy`
- `cabin(day-5): standardize terminology and fix empty states`
