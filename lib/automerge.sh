# shellcheck shell=bash disable=SC2034
# (SC2034: AM_* variables are read by the scripts that source this file.)
# lib/automerge.sh: shared by INSTALL.sh and sync.sh. Source it; do not run it.
#
# Both scripts compare a $HOME file with its repo twin. Instead of showing a
# diff and asking every time, am_classify works out what happened from the repo
# file's own git history, so each script only has to ask on a real conflict.
#
# Needs: git, diff, cmp. Uses $AM_TMP (created here, removed on exit).

AM_TMP="$(mktemp -d)"
trap 'rm -rf "$AM_TMP"' EXIT
AM_BASE="$AM_TMP/base"      # merge base picked by am_find_base
AM_MERGED="$AM_TMP/merged"  # result of a clean 3-way merge (verdict "merged")

# am_find_base <repo-file> <home-file>
#
# Writes to $AM_BASE the committed version of the repo file (last 30 commits
# that touched it, in whichever repo holds it, so the private checkout works
# too) closest to the home file. Sets AM_BASE_IS_HOME=1 when the home file IS
# one of those versions, i.e. home just has not had the newer version yet.
# Returns 1 when the file has no history (untracked, or not in a repo).
am_find_base() {
    local repo="$1" home="$2"
    local dir path sha n best_n=999999 cand="$AM_TMP/cand"
    AM_BASE_IS_HOME=0
    : >"$AM_BASE"
    dir="$(dirname "$repo")"
    path="$(git -C "$dir" ls-files --full-name -- "$(basename "$repo")" 2>/dev/null)"
    [ -n "$path" ] || return 1
    while read -r sha; do
        git -C "$dir" show "$sha:$path" >"$cand" 2>/dev/null || continue
        if cmp -s "$cand" "$home"; then
            cp "$cand" "$AM_BASE"; AM_BASE_IS_HOME=1; return 0
        fi
        n=$(diff "$cand" "$home" | grep -c '^[<>]' || true)
        # -le, not -lt: log runs newest first, so ties go to the OLDER version.
        # If both sides edited the same line, home is equally far from the old
        # and new versions; picking the new one as base would make the repo's
        # edit vanish in a "clean" merge. The older base surfaces a conflict.
        if [ "$n" -le "$best_n" ]; then best_n=$n; cp "$cand" "$AM_BASE"; fi
    done < <(git -C "$dir" log -n 30 --format=%H -- ":(top)$path")
    [ -s "$AM_BASE" ]
}

# am_classify <home-file> <repo-file>
#
# Sets AM_VERDICT to one of:
#   home_older  home equals an older committed version; the repo is newer
#   home_adds   home only adds lines to the repo version; home is newer
#   merged      both changed, in different places; clean result in $AM_MERGED
#   conflict    both changed the same lines (or no history to decide with)
# and AM_ADDS / AM_DELS to the line counts of home relative to repo.
# Callers decide what each verdict means in their direction.
am_classify() {
    local home="$1" repo="$2"
    AM_ADDS=$(diff "$repo" "$home" | grep -c '^>' || true)
    AM_DELS=$(diff "$repo" "$home" | grep -c '^<' || true)
    : >"$AM_MERGED"
    if am_find_base "$repo" "$home" && [ "$AM_BASE_IS_HOME" -eq 1 ]; then
        AM_VERDICT=home_older
    elif [ "$AM_DELS" -eq 0 ]; then
        AM_VERDICT=home_adds
    elif [ -s "$AM_BASE" ] && cp "$home" "$AM_MERGED" \
         && git merge-file -q "$AM_MERGED" "$AM_BASE" "$repo" 2>/dev/null; then
        AM_VERDICT=merged
    else
        AM_VERDICT=conflict
    fi
}

# am_list <title> [files...]: print one summary block, if any files are given.
# Call as: am_list "title" ${ARR[@]+"${ARR[@]}"}  (safe for empty arrays
# under set -u on macOS's bash 3.2).
am_list() {
    local title="$1"; shift
    [ "$#" -gt 0 ] || return 0
    printf '\033[1;34m[%s]\033[0m %s: %s\n' "$AM_TAG" "$title" "$#"
    printf '      %s\n' "$@"
}
