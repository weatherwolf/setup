#!/usr/bin/env bash
#
# bootstrap.sh - prepare a fresh machine, then install the dotfiles.
# Clones third-party tools that the configs depend on but that are NOT
# tracked in this repo, then runs install.sh to create the symlinks.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v git >/dev/null 2>&1; then
  echo "error: git is not installed or not on PATH" >&2
  exit 1
fi

# powerlevel10k: third-party zsh theme sourced from ~/.zshrc. Clone from
# upstream (not vendored here). Skip if already present.
P10K_DIR="$HOME/powerlevel10k"
if [[ -d "$P10K_DIR/.git" ]]; then
  echo "[ok]    powerlevel10k already present at $P10K_DIR"
else
  echo "[clone] powerlevel10k -> $P10K_DIR"
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

# Optionally install Claude Code (official native installer). Never let a
# failed/declined install abort the rest of bootstrap: '|| reply=""' handles a
# non-interactive stdin (EOF), and the install runs in its own guarded block.
read -rp 'Install Claude Code on this machine? [y/N] ' reply || reply=""
if [[ "$reply" == [Yy]* ]]; then
  echo "[install] Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash || echo "  [warn] Claude Code install failed; continuing"
fi

echo
echo "Running install.sh..."
"$REPO_DIR/install.sh"
