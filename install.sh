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
  "starship/.config/starship.toml|$HOME/.config/starship.toml"
  "tmux/.tmux.conf|$HOME/.tmux.conf"
  "herdr/.config/herdr/config.toml|$HOME/.config/herdr/config.toml"
  "nvim/.config/nvim|$HOME/.config/nvim"
  "claude/.claude/CLAUDE.md|$HOME/.claude/CLAUDE.md"
  "claude/.claude/settings.json|$HOME/.claude/settings.json"
  # Custom Claude Code theme. The slug is the FILENAME, not the "name" field, so
  # glacier_wave.json is what settings.json's "custom:glacier_wave" resolves to.
  # The themes dir is file-watched, so edits to the repo file hot-reload. Edit
  # the repo file, not /theme -- its built-in editor writes to this directory
  # and would replace the symlink with a regular file.
  "claude/.claude/themes/glacier_wave.json|$HOME/.claude/themes/glacier_wave.json"
  "claude/.claude/statusline.py|$HOME/.claude/statusline.py"
  "claude/.claude/hooks|$HOME/.claude/hooks"
  # Skill manifest only. The skill *content* under ~/.claude/skills is owned by
  # the `skills` CLI (npx skills), so ~/.claude/skills is deliberately NOT linked
  # here -- linking it would clobber the npx-managed directory on install.
  "claude/.agents/.skill-lock.json|$HOME/.agents/.skill-lock.json"
  # Vendored local skills (not in the lockfile): hand-made ones that were
  # never installed via npx skills, plus ones whose upstream source deleted
  # them so the CLI can no longer reinstall them. Content lives in this repo.
  # Each needs two links: its real location under ~/.agents/skills and the
  # per-skill entry inside ~/.claude/skills that Claude Code actually reads.
  # Linking individual entries does not clobber the npx-managed directory.
  "claude/.agents/skills/find-convo|$HOME/.agents/skills/find-convo"
  "claude/.agents/skills/find-convo|$HOME/.claude/skills/find-convo"
  "claude/.agents/skills/rename-smart|$HOME/.agents/skills/rename-smart"
  "claude/.agents/skills/rename-smart|$HOME/.claude/skills/rename-smart"
  "claude/.agents/skills/decision-mapping|$HOME/.agents/skills/decision-mapping"
  "claude/.agents/skills/decision-mapping|$HOME/.claude/skills/decision-mapping"
  "claude/.agents/skills/to-issues|$HOME/.agents/skills/to-issues"
  "claude/.agents/skills/to-issues|$HOME/.claude/skills/to-issues"
  "claude/.agents/skills/to-prd|$HOME/.agents/skills/to-prd"
  "claude/.agents/skills/to-prd|$HOME/.claude/skills/to-prd"
)

# Back up an existing real file/dir, then symlink src -> dst.
link() {
  local src="$1" dst="$2"

  if [[ ! -e "$src" ]]; then
    echo "  [skip]   source missing in repo: $src"
    return
  fi
  # Already pointing at the right place: nothing to do. Compare the link target
  # to $src directly (we always link with an absolute $src); portable, since
  # macOS/BSD readlink has no -f.
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
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

echo "Done. (Run ./bootstrap.sh first on a fresh machine to install starship.)"
