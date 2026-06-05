#!/usr/bin/env bash
#
# install_configs.sh — clone (or update) my config repos from GitHub, then
# symlink each config into its target location. Re-runnable. Backs up any
# existing real file before replacing it.
#
set -euo pipefail

GH_USER="weatherwolf"
# Where the repos get cloned. Override with: CONFIG_REPO_DIR=/path ./install_configs.sh
REPO_DIR="${CONFIG_REPO_DIR:-$HOME/.config-repos}"

# Repos to clone/update.
REPOS=(
  "Neovim-Configuration"
  "tmux_configuration"
  "wezterm_configuration"
)

# Symlinks to create:  <source within $REPO_DIR>  =>  <target>
# (one "src|dst" pair per line)
LINKS=(
  "tmux_configuration/.tmux.conf|$HOME/.tmux.conf"
  "Neovim-Configuration/init.lua|$HOME/.config/nvim/init.lua"
  "Neovim-Configuration/lazy-lock.json|$HOME/.config/nvim/lazy-lock.json"
  "wezterm_configuration/wezterm.lua|$HOME/.config/wezterm/wezterm.lua"
)

ts="$(date +%Y%m%d-%H%M%S)"

# Clone a repo, or fast-forward it if already present.
clone_or_update() {
  local repo="$1" dest="$REPO_DIR/$repo"
  if [[ -d "$dest/.git" ]]; then
    echo "  ⟳ updating $repo"
    git -C "$dest" pull --ff-only
  else
    echo "  ⬇ cloning $repo"
    git clone "https://github.com/$GH_USER/$repo.git" "$dest"
  fi
}

# Back up an existing real file, then symlink src -> dst.
link() {
  local src="$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  ✗ source missing, skipping: $src"
    return
  fi
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "  = already linked: $dst"
    return
  fi
  if [[ -e "$dst" || -L "$dst" ]]; then
    mv "$dst" "$dst.bak.$ts"
    echo "  ↳ backed up existing $dst -> $dst.bak.$ts"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  ✓ linked $dst -> $src"
}

echo "Cloning/updating repos into $REPO_DIR:"
mkdir -p "$REPO_DIR"
for repo in "${REPOS[@]}"; do
  clone_or_update "$repo"
done

echo "Linking configs:"
for pair in "${LINKS[@]}"; do
  link "$REPO_DIR/${pair%%|*}" "${pair#*|}"
done

echo "Done."
