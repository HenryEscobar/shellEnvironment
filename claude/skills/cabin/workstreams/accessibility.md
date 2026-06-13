# Day 10: Accessibility

## Focus
ARIA labels, screen reader support, color contrast, keyboard navigation, focus management.

## Skip Conditions
- No UI in the project → SKIP this workstream entirely
- CLI tool → limited applicability, focus only on color contrast and screen reader output

## What to Check and Fix

### ARIA Labels
- Interactive elements (buttons, links, inputs) need accessible labels
- Icon-only buttons need `aria-label` or `accessibilityLabel`
- Form inputs need associated labels (`htmlFor`/`accessibilityLabel`)
- Decorative images: `aria-hidden="true"` or `role="presentation"`

### Screen Reader Support
- Meaningful content order in the DOM/component tree
- Dynamic content changes announced (`aria-live`, `accessibilityLiveRegion`)
- Modal/dialog focus trapping
- Navigation landmarks (`role="navigation"`, `role="main"`, etc.)

### Color Contrast
- Text meets WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text)
- Don't rely on color alone to convey information (add icons, patterns, or text)
- Check error states, disabled states, placeholder text

### Keyboard Navigation (Web)
- All interactive elements reachable via Tab
- Logical tab order
- Escape closes modals/dropdowns
- Enter/Space activates buttons
- Arrow keys for lists/menus if applicable

### Focus Management
- Focus moves to new content when navigating (modals, page transitions)
- Focus returns to trigger element when modal closes
- Visible focus indicators (don't remove `outline` without replacement)
- Skip-to-content link for web apps

### React Native Specific
- `accessibilityLabel` on touchable/pressable components
- `accessibilityRole` for semantic meaning
- `accessibilityState` for disabled, selected, checked states
- `accessibilityHint` for non-obvious interactions

## How to Make Changes

1. **ARIA labels first** — biggest impact, lowest risk
2. **Focus management second** — critical for keyboard/screen reader users
3. **Contrast fixes third** — may require design input for color choices
4. **Do not change visual design** — only add accessibility attributes and fix contrast
5. **Test with screen reader** if available, otherwise add attributes based on best practices
6. **Flag contrast issues** that need design decisions in "Manual Follow-up"

## Commit Message Format
```
cabin(day-10): [specific accessibility fix]
```

Examples:
- `cabin(day-10): add accessibility labels to interactive components`
- `cabin(day-10): fix focus management in modal and navigation flows`
