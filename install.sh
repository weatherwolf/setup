#!/usr/bin/env bash
#
# install.sh - symlink dotfiles from this repo into their default locations.
# Re-runnable and safe: any existing real file/dir is backed up (never deleted)
# before a symlink replaces it. Stale/incorrect symlinks are replaced.
#
# Usage:   ./install.sh
# The repo can live anywhere; paths are resolved relative to this script.
#
set -euo pipefail

# Absolute path to this repo (directory containing this script).
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ts="$(date +%Y%m%d-%H%M%S)"

# Symlinks to create:  <source within repo>|<target in $HOME>
# (one pair per line)
LINKS=(
  "zsh/.zshrc|$HOME/.zshrc"
  "zsh/.p10k.zsh|$HOME/.p10k.zsh"
  "tmux/.tmux.conf|$HOME/.tmux.conf"
  "nvim/.config/nvim|$HOME/.config/nvim"
  "claude/.claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "claude/.claude/settings.json|$HOME/.claude/settings.json"
  "claude/.claude/statusline.py|$HOME/.claude/statusline.py"
  "claude/.claude/skills|$HOME/.claude/skills"
  "claude/.claude/hooks|$HOME/.claude/hooks"
)

# Back up an existing real file/dir, then symlink src -> dst.
link() {
  local src="$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  [skip]   source missing in repo: $src"
    return
  fi
  # Already pointing at the right place: nothing to do.
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "  [ok]     already linked: $dst"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" ]]; then
    rm -f "$dst"
    echo "  [relink] removed stale link: $dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "$dst.bak.$ts"
    echo "  [backup] $dst -> $dst.bak.$ts"
  fi

  ln -s "$src" "$dst"
  echo "  [link]   $dst -> $src"
}

echo "Linking dotfiles from $REPO_DIR:"
for pair in "${LINKS[@]}"; do
  link "$REPO_DIR/${pair%%|*}" "${pair#*|}"
done

echo "Done. (Run ./bootstrap.sh first on a fresh machine to install powerlevel10k.)"
