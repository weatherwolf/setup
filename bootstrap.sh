#!/usr/bin/env bash
#
# bootstrap.sh - prepare a fresh machine, then install the dotfiles.
# Clones third-party tools that the configs depend on but that are NOT
# tracked in this repo, then runs install.sh to create the symlinks.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use sudo only when not already root (root sessions / containers have no sudo).
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then SUDO="sudo"; fi

# Install prerequisites (Debian/Ubuntu only). Each package is installed just
# once, and skipped if already present.
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for pkg in git curl zsh; do
    command -v "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    echo "[deps]  installing: ${missing[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${missing[@]}"
  fi
fi

# Final guard: git is required regardless of distro.
if ! command -v git >/dev/null 2>&1; then
  echo "error: git is not installed or not on PATH" >&2
  exit 1
fi

# Make zsh the login shell if it isn't already (so ~/.zshrc actually loads).
zsh_path="$(command -v zsh || true)"
if [[ -n "$zsh_path" && "$SHELL" != "$zsh_path" ]]; then
  echo "[chsh]  setting login shell to zsh (may prompt for your password)"
  chsh -s "$zsh_path" || echo "  [warn] chsh failed; run 'chsh -s $zsh_path' manually"
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

echo
echo "All set. Start a fresh shell to load the new config: exec zsh"
echo "(Or just open a new terminal. If chsh ran, a full re-login applies it everywhere.)"
