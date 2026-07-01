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

# Prerequisites (Debian/Ubuntu). Package names, not binary names:
#   git/curl/zsh   - shell + clone tooling
#   neovim/tmux    - editors the configs are for
#   build-essential- compiler + make, for telescope-fzf-native (build = 'make')
#   ripgrep        - live_grep backend for telescope and fzf-lua  (binary: rg)
#   fd-find        - faster file finding for telescope/fzf-lua     (binary: fdfind)
#   fzf            - required by the fzf-lua plugin
#   python3-pynvim - remote-plugin support for wilder.nvim (:UpdateRemotePlugins)
#   xclip          - system clipboard on X11 (tmux/nvim, non-SSH)
#   wl-clipboard   - system clipboard on Wayland
PACKAGES=(git curl zsh neovim tmux build-essential ripgrep fd-find fzf
          python3-pynvim xclip wl-clipboard)

# Install only packages not already present (checked by package name via dpkg).
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for pkg in "${PACKAGES[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    echo "[deps]  installing: ${missing[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${missing[@]}"
  fi
fi

# Debian installs fd as 'fdfind'; telescope/fzf-lua look for 'fd'. Bridge it.
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  echo "[link]  fd -> $(command -v fdfind)"
fi

# MesloLGS Nerd Font (recommended by powerlevel10k; needed for nvim icons).
# Only useful where the terminal renders LOCALLY. On a remote/SSH VM the font
# must instead live on your local machine, so this is skipped when fontconfig
# (fc-cache) is absent.
if command -v fc-cache >/dev/null 2>&1; then
  font_dir="$HOME/.local/share/fonts"
  if [[ ! -f "$font_dir/MesloLGS NF Regular.ttf" ]]; then
    echo "[font]  installing MesloLGS NF -> $font_dir"
    mkdir -p "$font_dir"
    base="https://github.com/romkatv/powerlevel10k-media/raw/master"
    curl -fsSL "$base/MesloLGS%20NF%20Regular.ttf"       -o "$font_dir/MesloLGS NF Regular.ttf"      || echo "  [warn] font download failed"
    curl -fsSL "$base/MesloLGS%20NF%20Bold.ttf"          -o "$font_dir/MesloLGS NF Bold.ttf"         || echo "  [warn] font download failed"
    curl -fsSL "$base/MesloLGS%20NF%20Italic.ttf"        -o "$font_dir/MesloLGS NF Italic.ttf"       || echo "  [warn] font download failed"
    curl -fsSL "$base/MesloLGS%20NF%20Bold%20Italic.ttf" -o "$font_dir/MesloLGS NF Bold Italic.ttf"  || echo "  [warn] font download failed"
    fc-cache -f >/dev/null 2>&1 || true
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

# TPM (Tmux Plugin Manager): third-party, required by ~/.tmux.conf to load its
# plugins. Clone from upstream (not vendored). After tmux starts, press
# prefix + I (Ctrl-a then Shift-i) to install the plugins.
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
  echo "[ok]    tpm already present at $TPM_DIR"
else
  echo "[clone] tpm -> $TPM_DIR"
  git clone --depth=1 https://github.com/tmux-plugins/tpm.git "$TPM_DIR"
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

# Reproduce the Claude Code skill set from the tracked manifest. install.sh (run
# just above) symlinks ~/.agents/.skill-lock.json to the copy in this repo. The
# CLI's `experimental_install` only restores *project* lockfiles, so for this
# *global* manifest we parse it and re-add each source with its exact skill list
# (`skills add <source> -g -y -s <skill,skill,...>`). This is faithful to the
# recipe: only the skills recorded in the lockfile are installed. Requires npx
# (Node) and python3; skipped with a warning if either is absent. Never blocks.
LOCK="$HOME/.agents/.skill-lock.json"
if command -v npx >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  if [[ -f "$LOCK" ]]; then
    echo "[skills] reproducing skill set from $LOCK"
    # Emit one "<source>\t<comma-separated skill names>" line per source.
    python3 - "$LOCK" <<'PY' | while IFS=$'\t' read -r source skills; do
import json, sys
from collections import defaultdict
data = json.load(open(sys.argv[1]))
by_source = defaultdict(list)
for name, info in data.get("skills", {}).items():
    by_source[info["source"]].append(name)
for source, names in by_source.items():
    print(source + "\t" + ",".join(sorted(names)))
PY
      [[ -z "$source" ]] && continue
      echo "  [skills] $source -> $skills"
      npx --yes skills add "$source" -g -y -s "$skills" \
        || echo "  [warn] failed to install skills from $source; run manually: npx skills add $source -g -y -s $skills"
    done || echo "  [warn] could not parse $LOCK; skipping skill install"
  else
    echo "  [warn] $LOCK missing; skipping skill install"
  fi
else
  echo "  [warn] npx or python3 not found; skipping skill install"
fi

echo
echo "All set. Start a fresh shell to load the new config: exec zsh"
echo "(Or just open a new terminal. If chsh ran, a full re-login applies it everywhere.)"
