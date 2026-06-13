# host-os/

macOS-specific bootstrap.

## What's here

| File | Purpose |
| --- | --- |
| `bootstrap.sh` | Installs Xcode CLT, Homebrew, runs `brew bundle`, then `npm-globals.sh` |
| `Brewfile` | Declarative list of CLI tools (and optional casks) |
| `npm-globals.sh` | Global npm CLIs you invoke from the shell (eas, gworkspace, ...) |

## Usage on a fresh Mac

```sh
./host-os/bootstrap.sh        # CLT + Homebrew + brew bundle
../INSTALL.sh                 # symlink dotfiles into ~
```

Re-run `bootstrap.sh` any time — it's idempotent.

## Editing the Brewfile

```sh
brew bundle --file=host-os/Brewfile         # install everything declared
brew bundle cleanup --file=host-os/Brewfile # show what's installed but not listed
```

Keep it lean. If you stop using something, delete the line instead of
commenting it out — the file should reflect what you actually use today.

## Global npm packages

`npm-globals.sh` lists `npm install -g` packages that are CLIs you invoke
directly (eas, gworkspace). MCP server runtimes don't belong here —
those go in `claude/mcp-servers.sh` and are invoked via `npx -y` so a
fresh machine pulls them on first use.

**EACCES on existing machines** — if your existing Node was installed from
nodejs.org (or another non-Homebrew path), `npm install -g` will fail with
permission errors because the prefix is root-owned. Two real fixes:

```sh
# Option A: switch to Homebrew Node
brew uninstall node  # if previously installed via brew (probably not)
# Then download-installed Node still owns /usr/local — easiest path is to
# uninstall the .pkg via Node's uninstaller, then:
brew install node

# Option B: point npm at a user-writable prefix (works alongside any Node)
npm config set prefix "$HOME/.npm-global"
# Add this line to ~/.zshrc-local:
export PATH="$HOME/.npm-global/bin:$PATH"
```
