# ~/.bashrc — interactive bash config.
# Shared aliases/functions live in ~/.shell_common (sourced by both shells).
# Machine-specific or secret bits live in ~/.bashrc-local (gitignored).

[ -f "$HOME/.shell_common" ] && . "$HOME/.shell_common"

# History
HISTSIZE=100000
HISTFILESIZE=100000
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend 2>/dev/null

# Machine-local overrides (LAST so they win).
[ -f "$HOME/.bashrc-local" ] && . "$HOME/.bashrc-local"
