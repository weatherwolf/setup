#!/usr/bin/env bash
#
# bootstrap.sh - prepare a fresh machine, then install the dotfiles.
# Clones third-party tools that the configs depend on but that are NOT
# tracked in this repo, then runs install.sh to create the symlinks.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# Use sudo only when not already root (root sessions / containers have no sudo).
SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then SUDO="sudo"; fi

# macOS prerequisites: Xcode Command Line Tools + Homebrew. These underpin the
# rest of the macOS path -- the Command Line Tools provide git and the compiler
# (needed to build telescope-fzf-native), and Homebrew installs the packages
# further below. For each: if it is already installed, offer to update it;
# otherwise offer to install it. Best-effort throughout -- a declined or failed
# step only warns, and '|| reply=""' keeps a non-interactive run (EOF on stdin)
# from aborting under 'set -e'.
if [[ "$OS" == "Darwin" ]]; then
  # Xcode Command Line Tools (git, cc, make). Full Xcode.app is not required by
  # any config here, so only the CLT are handled.
  if xcode-select -p >/dev/null 2>&1; then
    read -rp 'Xcode Command Line Tools are installed. Check for updates? [y/N] ' reply || reply=""
    if [[ "$reply" == [Yy]* ]]; then
      echo "[xcode] checking Software Update for Command Line Tools updates"
      if softwareupdate --list 2>/dev/null | grep -i 'command line tools'; then
        echo "  Update listed above; apply it via System Settings > General >"
        echo "  Software Update, or: softwareupdate -i '<label shown above>'"
      else
        echo "  [ok] no Command Line Tools updates listed"
      fi
    fi
  else
    read -rp 'Xcode Command Line Tools are not installed. Install them now? [y/N] ' reply || reply=""
    if [[ "$reply" == [Yy]* ]]; then
      echo "[xcode] launching the Command Line Tools installer"
      xcode-select --install || echo "  [warn] could not start installer (may already be in progress)"
      echo "  Complete the on-screen dialog, then re-run ./bootstrap.sh."
    fi
  fi

  # Homebrew (installs the packages listed further below).
  if command -v brew >/dev/null 2>&1; then
    read -rp 'Homebrew is installed. Update it now (brew update)? [y/N] ' reply || reply=""
    if [[ "$reply" == [Yy]* ]]; then
      echo "[brew]  brew update"
      brew update || echo "  [warn] brew update failed; continuing"
    fi
  else
    read -rp 'Homebrew is not installed. Install it now? [y/N] ' reply || reply=""
    if [[ "$reply" == [Yy]* ]]; then
      echo "[brew]  installing Homebrew"
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
        || echo "  [warn] Homebrew install failed; continuing"
      # A fresh install is not yet on PATH in this shell (Apple silicon uses
      # /opt/homebrew, Intel uses /usr/local); load it so the package step below
      # can find 'brew'.
      if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    fi
  fi
fi

# Prerequisites, per platform. Package names, not binary names.
# Debian/Ubuntu (apt):
#   git/curl/zsh    - shell + clone tooling
#   neovim/tmux     - editors the configs are for
#   build-essential - compiler + make, for telescope-fzf-native (build = 'make')
#   ripgrep         - live_grep backend for telescope and fzf-lua  (binary: rg)
#   fd-find         - faster file finding for telescope/fzf-lua     (binary: fdfind)
#   fzf             - required by the fzf-lua plugin
#   python3-pynvim  - remote-plugin support for wilder.nvim (:UpdateRemotePlugins)
#   jq              - JSON parsing used by the Claude Code hooks
#   xclip           - system clipboard on X11 (tmux/nvim, non-SSH)
#   wl-clipboard    - system clipboard on Wayland
#   nodejs + npm    - provide node and npx, required by the "reproduce the
#                     Claude Code skill set" step at the end of this script;
#                     without them that step is silently skipped
APT_PACKAGES=(git curl zsh neovim tmux build-essential ripgrep fd-find fzf
              python3-pynvim jq xclip wl-clipboard nodejs npm)

# macOS (Homebrew). git/curl/zsh ship with macOS (git via the Xcode Command
# Line Tools, which Homebrew itself requires), so only the extra tools are
# installed here. No clipboard packages: macOS provides pbcopy/pbpaste.
# telescope-fzf-native compiles with the CLT toolchain. pynvim (for wilder.nvim)
# is optional; install it with 'pip3 install --user pynvim' if you use
# :UpdateRemotePlugins. node provides npx for the skills reproduce step.
BREW_PACKAGES=(neovim tmux ripgrep fd fzf jq node)

# Install only packages not already present.
if command -v apt-get >/dev/null 2>&1; then
  missing=()
  for pkg in "${APT_PACKAGES[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if (( ${#missing[@]} )); then
    echo "[deps]  installing: ${missing[*]}"
    $SUDO apt-get update
    $SUDO apt-get install -y "${missing[@]}"
  fi
elif [[ "$OS" == "Darwin" ]]; then
  if command -v brew >/dev/null 2>&1; then
    missing=()
    for pkg in "${BREW_PACKAGES[@]}"; do
      brew list --formula "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done
    if (( ${#missing[@]} )); then
      echo "[deps]  installing: ${missing[*]}"
      brew install "${missing[@]}"
    fi
  else
    echo "[warn]  Homebrew not found; install it from https://brew.sh then re-run,"
    echo "        or install these manually: ${BREW_PACKAGES[*]}"
  fi
fi

# Debian installs fd as 'fdfind'; telescope/fzf-lua look for 'fd'. Bridge it.
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  echo "[link]  fd -> $(command -v fdfind)"
fi

# MesloLGS Nerd Font, needed for nvim's icons. The starship prompt config is
# deliberately ASCII-only, so it does not depend on this font. Only useful where
# the terminal renders LOCALLY. On a remote/SSH VM the font must instead live on
# your local machine. Fonts go to ~/Library/Fonts on macOS and to the fontconfig
# dir on Linux; skipped when neither applies. (Files are hosted in the
# powerlevel10k-media repo, which is just a convenient mirror of the font.)
font_dir=""
run_fc_cache=0
if [[ "$OS" == "Darwin" ]]; then
  font_dir="$HOME/Library/Fonts"
elif command -v fc-cache >/dev/null 2>&1; then
  font_dir="$HOME/.local/share/fonts"
  run_fc_cache=1
fi
if [[ -n "$font_dir" && ! -f "$font_dir/MesloLGS NF Regular.ttf" ]]; then
  echo "[font]  installing MesloLGS NF -> $font_dir"
  mkdir -p "$font_dir"
  base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  curl -fsSL "$base/MesloLGS%20NF%20Regular.ttf"       -o "$font_dir/MesloLGS NF Regular.ttf"      || echo "  [warn] font download failed"
  curl -fsSL "$base/MesloLGS%20NF%20Bold.ttf"          -o "$font_dir/MesloLGS NF Bold.ttf"         || echo "  [warn] font download failed"
  curl -fsSL "$base/MesloLGS%20NF%20Italic.ttf"        -o "$font_dir/MesloLGS NF Italic.ttf"       || echo "  [warn] font download failed"
  curl -fsSL "$base/MesloLGS%20NF%20Bold%20Italic.ttf" -o "$font_dir/MesloLGS NF Bold Italic.ttf"  || echo "  [warn] font download failed"
  [[ "$run_fc_cache" -eq 1 ]] && { fc-cache -f >/dev/null 2>&1 || true; }
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

# starship: cross-shell prompt, initialized at the end of ~/.zshrc. Third-party
# binary (not vendored here). Homebrew carries it on macOS; on Linux it is not
# reliably packaged, so fall back to the official installer. Skip if present.
# Never aborts bootstrap on failure -- without it ~/.zshrc just uses zsh's
# default prompt.
if command -v starship >/dev/null 2>&1; then
  echo "[ok]    starship already installed: $(command -v starship)"
elif command -v brew >/dev/null 2>&1; then
  echo "[install] starship (brew)"
  brew install starship || echo "  [warn] starship install failed; continuing"
else
  echo "[install] starship (https://starship.rs/install.sh)"
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes \
    || echo "  [warn] starship install failed; continuing"
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

# herdr: agent-aware terminal multiplexer used alongside tmux. Third-party
# binary (not in apt/brew here), installed via the official script, which
# downloads the right release for this platform and puts it on PATH. Skip if
# already present. Never aborts bootstrap on failure.
if command -v herdr >/dev/null 2>&1; then
  echo "[ok]    herdr already installed: $(command -v herdr)"
else
  echo "[install] herdr (https://herdr.dev/install.sh)"
  curl -fsSL https://herdr.dev/install.sh | sh || echo "  [warn] herdr install failed; continuing"
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
# (`skills add <source> -g -y -s <skill> -s <skill> ...`; the CLI needs one -s
# flag per skill, a comma-separated value silently matches nothing). Skills the
# source repo no longer offers are skipped by the CLI without failing the rest.
# This is faithful to the recipe: only the skills recorded in the lockfile are
# installed. Requires npx (Node) and python3; skipped with a warning if either
# is absent. Never blocks.
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
      IFS=',' read -ra names <<< "$skills"
      flags=()
      for name in "${names[@]}"; do flags+=(-s "$name"); done
      # </dev/null: npx must not inherit the loop's stdin, or it swallows the
      # remaining piped source lines and only the first source is installed.
      npx --yes skills add "$source" -g -y "${flags[@]}" </dev/null \
        || echo "  [warn] failed to install skills from $source; run manually: npx skills add $source -g -y ${flags[*]}"
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
