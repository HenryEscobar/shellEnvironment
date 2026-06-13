# ~/.zprofile — sourced once at login (before .zshrc).
# Put PATH/env setup that should also be visible to non-interactive login
# shells (e.g. scripts launched by GUI apps) here.

# Homebrew on Apple Silicon. The brew shellenv emits PATH, MANPATH, etc.
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Machine-local login env (gitignored).
[ -f "$HOME/.zprofile-local" ] && . "$HOME/.zprofile-local"
