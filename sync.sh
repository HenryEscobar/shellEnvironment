#!/bin/bash
# sync.sh — capture changes from $HOME back into this repo (home -> repo).
#
# Usage:
#   ./sync.sh                # interactive: show diff, ask per file
#   ./sync.sh --dry-run      # just list files that diverge; no prompts
#   ./sync.sh --all          # also walk claude/ (default: yes if claude/ exists)
#   ./sync.sh --no-claude    # skip claude/
#   ./sync.sh --mcp          # ONLY check MCP-server drift (no file diffs)
#
# For each file the repo tracks, compare with the matching file in $HOME:
#   - identical                  -> silently skip
#   - missing at home            -> warn, skip (repo has something home doesn't)
#   - differs                    -> show diff, prompt:
#       [o]verwrite repo with home version
#       [k]eep repo unchanged
#       [m]erge in $EDITOR (vimdiff by default), then re-prompt
#       [s]how diff again
#       [q]uit (stop processing further files)
#
# Nothing is overwritten without your explicit "o" or "m" + save.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
DO_CLAUDE=1
DO_FILES=1
DO_MCP=0
[ -d "$REPO_DIR/claude" ] || DO_CLAUDE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=1 ;;
        --all)        DO_CLAUDE=1 ;;
        --no-claude)  DO_CLAUDE=0 ;;
        --mcp)        DO_MCP=1; DO_FILES=0 ;;
        -h|--help)    sed -n '2,22p' "$0"; exit 0 ;;
        *)            echo "unknown flag: $arg" >&2; exit 2 ;;
    esac
done

log()  { printf '\033[1;34m[sync]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[sync]\033[0m %s\n' "$*" >&2; }

MERGE_TOOL="${EDITOR:-vimdiff}"
# If $EDITOR is set to something that isn't a diff tool (vim, nano, code...),
# fall back to a real 2-pane diff editor.
case "$MERGE_TOOL" in
    *vimdiff*|*nvim*-d*|*opendiff*|*meld*) ;;  # already diff-capable
    *) MERGE_TOOL="vimdiff" ;;
esac

# show_diff <home> <repo>
# Use git's colorized diff if available, else plain unified diff.
show_diff() {
    local home="$1" repo="$2"
    if command -v git >/dev/null 2>&1; then
        git --no-pager diff --no-index --color=always -- "$repo" "$home" || true
    else
        diff -u "$repo" "$home" || true
    fi
}

# handle_one <home> <repo>
handle_one() {
    local home="$1" repo="$2"
    local rel="${repo#"$REPO_DIR/"}"

    if [ ! -e "$home" ]; then
        warn "MISSING at home: $home  (repo has $rel; skipping)"
        return 0
    fi
    if [ -L "$home" ]; then
        warn "still a symlink at home: $home  (skipping; convert it first)"
        return 0
    fi
    if cmp -s "$home" "$repo"; then
        return 0  # identical
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  diverges: $rel"
        return 0
    fi

    while true; do
        echo
        log "$rel diverges. home: $home"
        show_diff "$home" "$repo" | sed -n '1,80p'
        local n
        n=$(show_diff "$home" "$repo" | wc -l | tr -d ' ')
        if [ "$n" -gt 80 ]; then echo "(diff truncated — $n lines total; pick [s] to see it again or [m] to view in editor)"; fi
        printf '\n  [o]verwrite repo  [k]eep repo  [m]erge in %s  [s]how full diff  [q]uit  > ' "$MERGE_TOOL"
        read -r choice </dev/tty
        case "$choice" in
            o|O)
                cp -p "$home" "$repo"
                log "wrote $rel from home"
                return 0
                ;;
            k|K)
                log "kept repo $rel unchanged"
                return 0
                ;;
            m|M)
                # Open repo vs home side-by-side. User saves merged result
                # into the REPO file (left pane). We never write home from here.
                "$MERGE_TOOL" "$repo" "$home" </dev/tty >/dev/tty 2>&1 || true
                if cmp -s "$home" "$repo"; then
                    log "merged $rel (now identical)"
                    return 0
                else
                    log "still diverges after merge — re-prompting"
                    # fall through to next loop iteration
                fi
                ;;
            s|S)
                show_diff "$home" "$repo" | ${PAGER:-less -R}
                ;;
            q|Q)
                warn "quit — remaining files left as-is"
                exit 0
                ;;
            *)
                echo "  pick o / k / m / s / q"
                ;;
        esac
    done
}

# --- File diff mode ---------------------------------------------------------
if [ "$DO_FILES" -eq 1 ]; then
    DOTFILES=(
        .shell_common .bashrc .zshrc .zprofile
        .tmux.conf .tmux.reset .screenrc .gitconfig
    )

    log "scanning dotfiles..."
    for f in "${DOTFILES[@]}"; do
        [ -f "$REPO_DIR/$f" ] || continue
        handle_one "$HOME/$f" "$REPO_DIR/$f"
    done

    if [ -f "$REPO_DIR/.ssh/config" ]; then
        handle_one "$HOME/.ssh/config" "$REPO_DIR/.ssh/config"
    fi

    if [ "$DO_CLAUDE" -eq 1 ] && [ -d "$REPO_DIR/claude" ]; then
        log "scanning claude/..."
        while IFS= read -r -d '' src; do
            rel="${src#"$REPO_DIR/claude/"}"
            case "$rel" in
                README.md|*/.gitkeep|.gitkeep|mcp-servers.sh) continue ;;
            esac
            handle_one "$HOME/.claude/$rel" "$src"
        done < <(find "$REPO_DIR/claude" -type f -print0)
    fi
fi

# --- MCP drift mode ---------------------------------------------------------
if [ "$DO_MCP" -eq 1 ]; then
    log "checking MCP-server drift..."
    if ! command -v claude >/dev/null 2>&1; then
        warn "claude CLI not on PATH; skipping MCP check."
    elif [ ! -f "$REPO_DIR/claude/mcp-servers.sh" ]; then
        warn "no claude/mcp-servers.sh in repo; skipping."
    else
        # Names installed locally at user scope. `claude mcp list` prints lines
        # like "name: command args - status"; pull the leading name.
        # Exclude claude.ai-managed entries (they have spaces and a colon-URL
        # pattern, e.g. "claude.ai Gmail: https://..."), since those follow
        # the claude.ai account and aren't managed by mcp-servers.sh.
        local_names=$(claude mcp list 2>/dev/null \
            | sed -n 's/^\([^[:space:]:][^:]*\):.*$/\1/p' \
            | grep -v '^claude\.ai ' \
            | sort -u)
        # Names declared in the script: grep `add_user_mcp <name>` lines.
        repo_names=$(grep -E '^[[:space:]]*add_user_mcp[[:space:]]+[^[:space:]]+' \
            "$REPO_DIR/claude/mcp-servers.sh" \
            | awk '{print $2}' \
            | sort -u)

        local_only=$(comm -23 <(printf '%s\n' "$local_names") <(printf '%s\n' "$repo_names"))
        repo_only=$( comm -13 <(printf '%s\n' "$local_names") <(printf '%s\n' "$repo_names"))

        if [ -z "$local_only" ] && [ -z "$repo_only" ]; then
            log "MCP servers in sync (local user-scope matches mcp-servers.sh)"
        else
            if [ -n "$local_only" ]; then
                echo
                warn "Installed locally but NOT in mcp-servers.sh — add them so the next machine gets them:"
                printf '  %s\n' $local_only
                echo "  hint: claude mcp get <name>   # to see the command + args to declare"
            fi
            if [ -n "$repo_only" ]; then
                echo
                warn "Declared in mcp-servers.sh but NOT installed locally — run the script to install:"
                printf '  %s\n' $repo_only
                echo "  hint: ./claude/mcp-servers.sh"
            fi
        fi
        echo
        warn "note: name-only drift. Same name with a different command on each side won't be flagged."
    fi
fi

log "Done."
if [ "$DRY_RUN" -eq 1 ]; then
    warn "Dry run — no changes made. Re-run without --dry-run to act on diffs."
elif [ "$DO_FILES" -eq 1 ]; then
    log "Review with: git -C '$REPO_DIR' diff"
fi
