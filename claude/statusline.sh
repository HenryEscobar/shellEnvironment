#!/bin/bash
input=$(cat)

# Colors
RESET='\033[0m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
MAGENTA='\033[35m'
BLUE='\033[34m'
DIM='\033[2m'

# Extract all values in a single jq call using newline delimiter
VALUES=$(echo "$input" | jq -r '
  (.model.display_name // "?"),
  (.cost.total_cost_usd // 0),
  (.workspace.current_dir // "."),
  ((.context_window.used_percentage // 0) | floor),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.cost.total_duration_ms // 0),
  (.cost.total_api_duration_ms // 0),
  (.agent.name // ""),
  (.worktree.name // "")
')

# Read line by line
MODEL=$(sed -n '1p' <<< "$VALUES")
COST=$(sed -n '2p' <<< "$VALUES")
DIR=$(sed -n '3p' <<< "$VALUES")
PERCENT=$(sed -n '4p' <<< "$VALUES")
LINES_ADD=$(sed -n '5p' <<< "$VALUES")
LINES_REM=$(sed -n '6p' <<< "$VALUES")
DURATION_MS=$(sed -n '7p' <<< "$VALUES")
API_MS=$(sed -n '8p' <<< "$VALUES")
AGENT=$(sed -n '9p' <<< "$VALUES")
WORKTREE=$(sed -n '10p' <<< "$VALUES")

# Get git branch
BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
fi
BRANCH=${BRANCH:-"no-repo"}

# Directory name only
DIR_NAME=${DIR##*/}

# Progress bar (10 chars)
BAR_WIDTH=10
FILLED=$((PERCENT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
if [ "$PERCENT" -ge 80 ]; then
    BAR_COLOR="$RED"
elif [ "$PERCENT" -ge 50 ]; then
    BAR_COLOR="$YELLOW"
else
    BAR_COLOR="$GREEN"
fi
BAR=$(printf '%*s' "$FILLED" '' | tr ' ' '█')$(printf '%*s' "$EMPTY" '' | tr ' ' '░')

# Format cost
COST_FMT=$(printf "%.2f" "$COST")

# Format duration (minutes)
DURATION_MIN=$((DURATION_MS / 60000))
if [ "$DURATION_MIN" -ge 60 ]; then
    DURATION_FMT="$((DURATION_MIN / 60))h$((DURATION_MIN % 60))m"
else
    DURATION_FMT="${DURATION_MIN}m"
fi

# Format API wait time
API_SEC=$((API_MS / 1000))
if [ "$API_SEC" -ge 60 ]; then
    API_MIN=$((API_SEC / 60))
    API_REM=$((API_SEC % 60))
    API_FMT="${API_MIN}m${API_REM}s"
else
    API_FMT="${API_SEC}s"
fi

# Lines changed
LINES_CHANGED="${GREEN}+${LINES_ADD}${RESET}/${RED}-${LINES_REM}${RESET}"

# Build prefix (agent/worktree if active)
PREFIX=""
if [ -n "$AGENT" ]; then
    PREFIX="${MAGENTA}${AGENT}${RESET} ${DIM}│${RESET} "
elif [ -n "$WORKTREE" ]; then
    PREFIX="${MAGENTA}wt:${WORKTREE}${RESET} ${DIM}│${RESET} "
fi

# Left: [agent/worktree] branch, dir, context bar
LEFT="${PREFIX}${CYAN}${BRANCH}${RESET} ${DIM}│${RESET} ${BLUE}${DIR_NAME}${RESET} ${DIM}│${RESET} ${BAR_COLOR}${BAR}${RESET} ${PERCENT}%"

# Right: lines, model, cost, duration (api wait)
RIGHT="${LINES_CHANGED} ${DIM}│${RESET} ${MAGENTA}${MODEL}${RESET} ${DIM}│${RESET} ${GREEN}\$${COST_FMT}${RESET} ${DIM}│${RESET} ${DIM}${DURATION_FMT} (${API_FMT} api)${RESET}"

echo -e "${LEFT} ${DIM}│${RESET} ${RIGHT}"
