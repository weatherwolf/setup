#!/usr/bin/env bash
#
# install_config.sh - clone (or update) my config repos from GitHub, then
# symlink each config into its target location. Re-runnable. Backs up any
# existing real file before replacing it.
#
# Linux only for now (also works under WSL/Git Bash). A native Windows
# installer (PowerShell) can be added later.
#
set -euo pipefail

GH_USER="weatherwolf"
# Where the repos get cloned. Override with: CONFIG_REPO_DIR=/path ./install_config.sh
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

# Make sure git is available before we try to use it.
if ! command -v git >/dev/null 2>&1; then
  echo "error: git is not installed or not on PATH" >&2
  exit 1
fi

# Clone a repo, or fast-forward it if already present.
clone_or_update() {
  local repo="$1" dest="$REPO_DIR/$repo"
  if [[ -d "$dest/.git" ]]; then
    echo "  [update] $repo"
    # Do not abort the whole run if the repo has local commits / diverged.
    git -C "$dest" pull --ff-only \
      || echo "  [warn] could not fast-forward $repo (local changes?); skipping update"
  else
    echo "  [clone]  $repo"
    git clone "https://github.com/$GH_USER/$repo.git" "$dest"
  fi
}

# Back up an existing real file, then symlink src -> dst.
link() {
  local src="$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  [skip]   source missing: $src"
    return
  fi
  # Already pointing at the right place: nothing to do.
  if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
    echo "  [ok]     already linked: $dst"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" ]]; then
    # Stale/incorrect symlink: just remove it, no point backing up a link.
    rm -f "$dst"
    echo "  [relink] removed stale link: $dst"
  elif [[ -e "$dst" ]]; then
    # Real file or directory: preserve it.
    mv "$dst" "$dst.bak.$ts"
    echo "  [backup] $dst -> $dst.bak.$ts"
  fi

  ln -s "$src" "$dst"
  echo "  [link]   $dst -> $src"
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
