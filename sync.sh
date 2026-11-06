#!/bin/bash
# sync.sh — capture changes from $HOME back into this repo (home -> repo).
#
# Usage:
#   ./sync.sh                # interactive: show diff, ask per file
#   ./sync.sh --dry-run      # just list files that diverge; no prompts
#   ./sync.sh --all          # also walk claude/ (default: yes if claude/ exists)
#   ./sync.sh --no-claude    # skip claude/
#   ./sync.sh --no-adopt     # skip the new-skill pass (see below)
#   ./sync.sh --mcp          # ONLY check MCP-server drift (no file diffs)
#   ./sync.sh --no-private   # skip the private pass (see below)
#   ./sync.sh --private      # ONLY run the private pass
#   ./sync.sh --no-brew      # skip the Homebrew pass (see below)
#   ./sync.sh --brew         # ONLY run the Homebrew pass
#
# For each file the repo tracks, compare with the matching file in $HOME:
#   - identical                  -> silently skip
#   - missing at home            -> warn, skip (repo has something home doesn't)
#   - differs                    -> decided automatically where that is safe,
#     using the file's git history as the merge base:
#       home is an older committed version  -> leave repo alone
#       home only adds lines                -> take home
#       both changed, in different places   -> 3-way merge into the repo
#     and only a real conflict (same lines changed on both sides) prompts:
#       [o]verwrite repo  [k]eep repo  [m]erge in $EDITOR  [s]how diff  [q]uit
#   A summary of every decision prints at the end; `git diff` reviews it.
#
# That walk is repo-driven: it finds files under claude/ in THIS repo and looks
# for their twins at home. A skill created only at $HOME is therefore invisible
# to it, which has silently dropped skills twice. A second pass walks
# $HOME/.claude/skills/*/ and offers any directory with no repo counterpart:
#       [a]dopt into repo
#       [k]eep out
#       [v]iew its SKILL.md
#       [q]uit
# Symlinked skills (owned by another repo) and gitignored paths are skipped.
#
# This repo is PUBLIC, so some files worth carrying between machines cannot live
# here: per-project memories (~/.claude/projects/*/memory/) and gitignored skill
# data. A private pass copies those into a separate private checkout
# ($SHELLENV_PRIVATE_DIR, default ../shellEnvironment-private). That pass is
# home-driven, so new files are found: new ones are copied without a prompt
# (nothing is overwritten), differing ones get the same automatic handling.
# Skipped with a warning when the private checkout does not exist.
#
# A Homebrew pass lists what you installed (brew leaves --installed-on-request,
# casks) that host-os/Brewfile does not name, and offers to add it. Anything you
# decline is written as a commented line, so it is never offered again.
#
# Automatic decisions keep both sides' changes; the repo is in git, so
# `git restore` undoes any of them. Nothing at $HOME is ever written.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
DO_CLAUDE=1
DO_FILES=1
DO_MCP=0
DO_ADOPT=1
DO_PRIVATE=1
DO_BREW=1
[ -d "$REPO_DIR/claude" ] || DO_CLAUDE=0
PRIVATE_DIR="${SHELLENV_PRIVATE_DIR:-$(dirname "$REPO_DIR")/shellEnvironment-private}"
# Which private repo to clone there. Defaults to the same GitHub owner as this
# checkout's origin, so a fork points at the forker's own private repo.
PRIVATE_REPO="${SHELLENV_PRIVATE_REPO:-}"
if [ -z "$PRIVATE_REPO" ]; then
    origin_owner="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null \
        | sed -nE 's#.*github\.com[:/]([^/]+)/.*#\1#p')"
    PRIVATE_REPO="${origin_owner:-<your-github-user>}/shellEnvironment-private"
fi

for arg in "$@"; do
    case "$arg" in
        --dry-run)    DRY_RUN=1 ;;
        --all)        DO_CLAUDE=1 ;;
        --no-claude)  DO_CLAUDE=0 ;;
        --no-adopt)   DO_ADOPT=0 ;;
        --mcp)        DO_MCP=1; DO_FILES=0; DO_PRIVATE=0; DO_BREW=0 ;;
        --no-private) DO_PRIVATE=0 ;;
        --private)    DO_PRIVATE=1; DO_FILES=0; DO_BREW=0 ;;
        --no-brew)    DO_BREW=0 ;;
        --brew)       DO_BREW=1; DO_FILES=0; DO_PRIVATE=0 ;;
        -h|--help)    sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
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

# shellcheck source=lib/automerge.sh
. "$REPO_DIR/lib/automerge.sh"
AM_TAG=sync
SUM_TAKEN=(); SUM_MERGED=(); SUM_STALE=(); SUM_ASKED=()

# print_summary: one block at the end instead of a diff per file.
print_summary() {
    [ "$DRY_RUN" -eq 1 ] && return 0
    am_list "took home version (home only added lines)" ${SUM_TAKEN[@]+"${SUM_TAKEN[@]}"}
    am_list "merged both sides automatically (no overlapping edits)" ${SUM_MERGED[@]+"${SUM_MERGED[@]}"}
    [ "${#SUM_MERGED[@]}" -gt 0 ] && warn "  home lacks the repo side of those; ./INSTALL.sh brings the merged result home"
    am_list "repo already newer than home, left alone" ${SUM_STALE[@]+"${SUM_STALE[@]}"}
    am_list "real conflicts you were asked about" ${SUM_ASKED[@]+"${SUM_ASKED[@]}"}
    return 0
}

# handle_one <home> <repo>
#
# Decides by itself where it safely can, and only asks on a real conflict:
#   home_older  home equals an older committed version -> leave repo alone
#   home_adds   home only adds lines                   -> take home
#   merged      both changed, different places         -> 3-way merge into repo
#   conflict    both changed the same lines            -> o/k/m/s/q prompt
# The classification lives in lib/automerge.sh, shared with INSTALL.sh.
# Every automatic outcome keeps both sides' changes, and the repo is in git, so
# `git diff` / `git restore` review or undo any of it.
handle_one() {
    local home="$1" repo="$2"
    local rel="${repo#"$REPO_DIR/"}"
    rel="${rel#"$PRIVATE_DIR/"}"

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

    am_classify "$home" "$repo"
    local adds="$AM_ADDS" dels="$AM_DELS"

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  $AM_VERDICT: $rel (home +$adds -$dels vs repo)"
        return 0
    fi

    case "$AM_VERDICT" in
        home_older)                     # repo is newer; INSTALL.sh's job
            SUM_STALE+=("$rel"); return 0 ;;
        home_adds)                      # taking home loses nothing
            cp -p "$home" "$repo"; SUM_TAKEN+=("$rel"); return 0 ;;
        merged)
            if cmp -s "$AM_MERGED" "$repo"; then
                SUM_STALE+=("$rel")     # repo already holds home's changes
            else
                cat "$AM_MERGED" >"$repo"
                SUM_MERGED+=("$rel")
            fi
            return 0 ;;
    esac

    SUM_ASKED+=("$rel")
    while true; do
        echo
        log "$rel: both sides changed the same lines (home +$adds -$dels vs repo)"
        printf '  [o]verwrite repo  [k]eep repo  [m]erge in %s  [s]how diff  [q]uit  > ' "$MERGE_TOOL"
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

# adopt_one_skill <home-skill-dir>
#
# The claude/ walk is repo-driven, so a skill directory that exists only at $HOME
# is never visited by handle_one. This offers such a directory for adoption.
#
# Skips, in order: anything the repo already tracks (handle_one owns those),
# anything without a SKILL.md, and anything .gitignore excludes. Per-file ignore
# checks matter as much as the directory check: a skill can be adoptable while
# some of its contents (local-only identifiers, generated baselines) are not.
adopt_one_skill() {
    local home_dir="$1"
    local name; name="$(basename "$home_dir")"
    local repo_dir="$REPO_DIR/claude/skills/$name"

    if [ -e "$repo_dir" ]; then return 0; fi              # tracked; handle_one has it
    if [ ! -f "$home_dir/SKILL.md" ]; then return 0; fi   # not a skill
    if git -C "$REPO_DIR" check-ignore -q "claude/skills/$name"; then
        return 0                                          # deliberately untracked
    fi

    local -a files=()
    local f rel
    while IFS= read -r -d '' f; do
        rel="${f#"$home_dir/"}"
        if git -C "$REPO_DIR" check-ignore -q "claude/skills/$name/$rel"; then
            continue
        fi
        files+=("$f")
    done < <(find "$home_dir" -type f -print0)

    if [ "${#files[@]}" -eq 0 ]; then
        warn "skills/$name: every file is gitignored; not adopting"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  untracked skill: skills/$name (${#files[@]} file(s) adoptable)"
        return 0
    fi

    local choice
    while true; do
        echo
        log "skills/$name exists at home but not in this repo. Would add:"
        for f in "${files[@]}"; do echo "      claude/skills/$name/${f#"$home_dir/"}"; done
        printf '\n  [a]dopt into repo  [k]eep out  [v]iew SKILL.md  [q]uit  > '
        read -r choice </dev/tty
        case "$choice" in
            a|A)
                for f in "${files[@]}"; do
                    rel="${f#"$home_dir/"}"
                    mkdir -p "$repo_dir/$(dirname "$rel")"
                    cp -p "$f" "$repo_dir/$rel"
                done
                log "adopted skills/$name (${#files[@]} file(s))"
                return 0
                ;;
            k|K)
                log "left skills/$name untracked"
                return 0
                ;;
            v|V)
                ${PAGER:-less -R} "$home_dir/SKILL.md" </dev/tty >/dev/tty 2>&1 || true
                ;;
            q|Q)
                warn "quit — remaining files left as-is"
                exit 0
                ;;
            *)
                echo "  pick a / k / v / q"
                ;;
        esac
    done
}

# --- File diff mode ---------------------------------------------------------
if [ "$DO_FILES" -eq 1 ]; then
    DOTFILES=(
        .shell_common .bashrc .zshrc .zprofile
        .tmux.conf .tmux.reset .screenrc .gitconfig
        .config/git/ignore
    )

    log "scanning dotfiles..."
    for f in "${DOTFILES[@]}"; do
        [ -f "$REPO_DIR/$f" ] || continue
        handle_one "$HOME/$f" "$REPO_DIR/$f"
    done

    if [ -f "$REPO_DIR/.ssh/config" ]; then
        handle_one "$HOME/.ssh/config" "$REPO_DIR/.ssh/config"
    fi

    if [ -d "$REPO_DIR/bin" ]; then
        log "scanning bin/..."
        while IFS= read -r -d '' src; do
            handle_one "$HOME/bin/$(basename "$src")" "$src"
        done < <(find "$REPO_DIR/bin" -type f -print0)
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

    if [ "$DO_CLAUDE" -eq 1 ] && [ "$DO_ADOPT" -eq 1 ] && [ -d "$HOME/.claude/skills" ]; then
        log "scanning for skills that exist only at home..."
        symlinked=""
        while IFS= read -r -d '' d; do
            if [ -L "$d" ]; then
                # Owned by another repo (azores.tools, the gws install). Those have
                # their own version control; adopting a copy here would fork them.
                symlinked="$symlinked $(basename "$d")"
                continue
            fi
            adopt_one_skill "$d"
        done < <(find "$HOME/.claude/skills" -mindepth 1 -maxdepth 1 -print0)
        if [ -n "$symlinked" ]; then
            log "skipped symlinked skills (owned by other repos):$symlinked"
        fi
    fi
fi

# --- Private pass -----------------------------------------------------------
# Home paths (relative to ~/.claude/) that go to the private checkout, never here.
# Directories are walked recursively. Keep in step with the matching
# .gitignore entries, which stop the public walks from picking these up.
PRIVATE_PATHS=(
    skills/weekly-digest/routines.local.md
    skills/silent-change-audit/baselines
)

# Project dirs are named after the project's absolute path with every
# non-alphanumeric character turned into "-", so they embed the username
# (-Users-me-irad-x). The private repo stores the home prefix as the literal
# HOME, and INSTALL.sh expands it, so memories survive a different username.
# INSTALL.sh holds the reverse mapping; change both together.
HOME_KEY="$(printf '%s' "$HOME" | sed 's#[^A-Za-z0-9]#-#g')"

# portable_rel <claude/...>: claude/projects/-Users-me-irad-x/f -> claude/projects/HOME-irad-x/f
portable_rel() {
    local rel="$1" tail proj
    case "$rel" in
        claude/projects/*/*) ;;
        *) printf '%s' "$rel"; return 0 ;;
    esac
    tail="${rel#claude/projects/}"
    proj="${tail%%/*}"
    if [ "$proj" = "$HOME_KEY" ] || [ "${proj#"$HOME_KEY"-}" != "$proj" ]; then
        proj="HOME${proj#"$HOME_KEY"}"
    fi
    printf 'claude/projects/%s/%s' "$proj" "${tail#*/}"
}

# private_home_files: NUL-separated list of every home file the private pass owns.
private_home_files() {
    local p
    for p in "$HOME"/.claude/projects/*/memory; do
        [ -d "$p" ] && find "$p" -type f ! -name .DS_Store -print0
    done
    for p in "${PRIVATE_PATHS[@]}"; do
        [ -e "$HOME/.claude/$p" ] && find "$HOME/.claude/$p" -type f ! -name .DS_Store -print0
    done
    return 0
}

if [ "$DO_PRIVATE" -eq 1 ]; then
    if [ ! -d "$PRIVATE_DIR/.git" ]; then
        warn "no private checkout at $PRIVATE_DIR; skipping memories and local skill data."
        warn "  clone it: gh repo clone '$PRIVATE_REPO' '$PRIVATE_DIR'"
        warn "  (or point elsewhere with SHELLENV_PRIVATE_DIR / SHELLENV_PRIVATE_REPO, e.g. in ~/.zshrc-local)"
    else
        log "scanning private files (memories, local skill data) -> $PRIVATE_DIR..."
        added=0
        while IFS= read -r -d '' home_file; do
            rel="$(portable_rel "claude/${home_file#"$HOME/.claude/"}")"
            dest="$PRIVATE_DIR/$rel"
            if [ -e "$dest" ]; then
                handle_one "$home_file" "$dest"
            elif [ "$DRY_RUN" -eq 1 ]; then
                echo "  new: $rel"
            else
                mkdir -p "$(dirname "$dest")"
                cp -p "$home_file" "$dest"
                added=$((added + 1))
            fi
        done < <(private_home_files)
        [ "$added" -gt 0 ] && log "copied $added new private file(s)"
        [ "$DRY_RUN" -eq 1 ] || log "Review with: git -C '$PRIVATE_DIR' status"
    fi
fi

# --- Homebrew pass ----------------------------------------------------------
# host-os/Brewfile has no twin at $HOME, so the file walk never sees a new
# `brew install`. This compares what you asked brew for against the Brewfile.
# Any name in the Brewfile counts as known, commented out or not: a commented
# line is how "installed here, but not for every machine" is recorded.
BREWFILE="$REPO_DIR/host-os/Brewfile"

brew_append() {   # brew_append <kind> <name> <commented:0|1>
    if ! grep -q '^# --- Added by sync.sh' "$BREWFILE"; then
        printf '\n# --- Added by sync.sh (move into a section above when convenient) -----------\n' >>"$BREWFILE"
    fi
    if [ "$3" -eq 1 ]; then
        printf '# %s "%s"   # kept out by sync.sh %s\n' "$1" "$2" "$(date +%Y-%m-%d)" >>"$BREWFILE"
    else
        printf '%s "%s"\n' "$1" "$2" >>"$BREWFILE"
    fi
}

if [ "$DO_BREW" -eq 1 ]; then
    if ! command -v brew >/dev/null 2>&1; then
        warn "brew not on PATH; skipping Homebrew pass."
    elif [ ! -f "$BREWFILE" ]; then
        warn "no host-os/Brewfile; skipping Homebrew pass."
    else
        log "checking Homebrew installs against host-os/Brewfile..."
        known=$(sed -nE 's/^[[:space:]#]*(brew|cask)[[:space:]]+"([^"]+)".*/\1 \2/p' "$BREWFILE" | sort -u)
        if command -v jq >/dev/null 2>&1; then
            casks=$(brew info --cask --installed --json=v2 2>/dev/null | jq -r '.casks[].full_token')
        else
            casks=$(brew list --cask -1)
        fi
        installed=$( { brew leaves --installed-on-request | sed 's/^/brew /'
                       printf '%s\n' "$casks" | grep . | sed 's/^/cask /'; } | sort -u)
        missing=$(comm -23 <(printf '%s\n' "$installed") <(printf '%s\n' "$known"))

        if [ -z "$missing" ]; then
            log "Brewfile covers everything installed on request"
        elif [ "$DRY_RUN" -eq 1 ]; then
            printf '%s\n' "$missing" | sed 's/^/  not in Brewfile: /'
        else
            echo
            log "installed here but not in host-os/Brewfile:"
            printf '%s\n' "$missing" | sed 's/^/      /'
            printf '\n  [a]dd all  [p]ick one by one  [k]eep all out (never asked again)  [s]kip for now  > '
            read -r choice </dev/tty
            case "$choice" in
                a|A) while read -r kind name; do brew_append "$kind" "$name" 0; done <<<"$missing"
                     log "added to Brewfile" ;;
                k|K) while read -r kind name; do brew_append "$kind" "$name" 1; done <<<"$missing"
                     log "recorded as kept out" ;;
                p|P) while read -r kind name; do
                         printf '  %s %s: [a]dd  [k]eep out  [s]kip  > ' "$kind" "$name"
                         read -r c </dev/tty
                         case "$c" in
                             a|A) brew_append "$kind" "$name" 0 ;;
                             k|K) brew_append "$kind" "$name" 1 ;;
                         esac
                     done <<<"$missing" ;;
                *)   log "Brewfile left unchanged" ;;
            esac
        fi
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

print_summary
log "Done."
if [ "$DRY_RUN" -eq 1 ]; then
    warn "Dry run — no changes made. Re-run without --dry-run to act on diffs."
elif [ "$DO_FILES" -eq 1 ]; then
    log "Review with: git -C '$REPO_DIR' diff"
fi
