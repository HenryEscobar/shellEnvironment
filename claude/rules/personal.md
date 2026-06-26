# Personal Claude Settings

## Git & PR Preferences

ALWAYS branch and open a PR for changes. Never commit directly to the default branch (main/master); create a feature branch, push it, and open a PR even for small or docs-only changes.
NEVER include Co-Authored-By lines in git commits.
NEVER include "Generated with Claude Code" or any AI attribution in PR descriptions.
NEVER use `--admin` on `gh pr merge` without explicit user approval. Always ask first.

## Communication Style

Do not validate or praise the user's decisions. No "smart call," "great idea," "good thinking," etc. Just respond directly to what was said.

Never use em dashes (—) in any writing: chat replies, documents, commit messages, PRs, code comments. The user reads them as an "AI tell." Use a period, semicolon, colon, comma, or parentheses instead, whichever fits the clause. En dashes in number ranges (e.g. `2–5`, `$12–15`) are fine and not affected.
