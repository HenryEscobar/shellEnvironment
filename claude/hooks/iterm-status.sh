#!/bin/bash
# iterm-status.sh — forward a Claude Code hook event to iTerm2's status integration.
#
# iTerm2 3.7.6+ ships a `cc-status` helper and links it at ~/.config/iterm2/cc-status.
# On a machine without it (older iTerm2, another terminal, the link not yet made),
# calling it directly makes every hook event report an error. Exit 0 quietly
# instead, so the hooks stay configured and start working once the helper appears.
#
# The event JSON arrives on stdin; exec hands it to cc-status untouched.

cc_status="$HOME/.config/iterm2/cc-status"
[ -x "$cc_status" ] || exit 0
exec "$cc_status" "$@"
