# ~/.zshrc — interactive zsh config.
# Shared aliases/functions live in ~/.shell_common (sourced by both shells).
# Machine-specific or secret bits live in ~/.zshrc-local (gitignored).

# --- Shared --------------------------------------------------------------
[ -f "$HOME/.shell_common" ] && . "$HOME/.shell_common"

# --- History -------------------------------------------------------------
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# --- Completion ----------------------------------------------------------
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# --- Key bindings --------------------------------------------------------
bindkey -e   # emacs-style; change to `bindkey -v` for vi

# --- Prompt --------------------------------------------------------------
# Lean default prompt; if `starship` is installed it takes over.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else
    autoload -Uz vcs_info
    precmd() { vcs_info }
    zstyle ':vcs_info:git:*' formats ' (%b)'
    setopt PROMPT_SUBST
    PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%F{yellow}${vcs_info_msg_0_}%f $ '
fi

# --- Tool integrations (silent if not installed) -------------------------
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
[ -f "$HOME/.fzf.zsh" ] && . "$HOME/.fzf.zsh"

# --- Machine-local overrides (LAST so they win) --------------------------
[ -f "$HOME/.zshrc-local" ] && . "$HOME/.zshrc-local"
