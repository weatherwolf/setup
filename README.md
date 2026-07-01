# setup

My Linux dotfiles, managed as a single Git repo. Configs are kept at their
default paths via symlinks back into this repo, so editing a file through its
normal location (e.g. `~/.zshrc`) edits the tracked file here.

## Layout

The repo uses a Stow-compatible package layout (each top-level dir mirrors
`$HOME`), but installation uses a plain script with no dependencies.

```
zsh/.zshrc                 -> ~/.zshrc
zsh/.p10k.zsh              -> ~/.p10k.zsh
tmux/.tmux.conf            -> ~/.tmux.conf
nvim/.config/nvim          -> ~/.config/nvim
claude/.claude/CLAUDE.md   -> ~/.claude/CLAUDE.md
claude/.claude/settings.json -> ~/.claude/settings.json
claude/.claude/statusline.py -> ~/.claude/statusline.py
claude/.claude/skills         -> ~/.claude/skills      (directory)
claude/.claude/hooks          -> ~/.claude/hooks       (directory)
```

`skills/` and `hooks/` are symlinked as whole directories, so any skill or
hook you add later is tracked automatically. A hook also needs an entry under
`"hooks"` in `settings.json` (tracked) to actually run.

Machine-specific Claude overrides go in `~/.claude/settings.local.json`
(untracked; Claude merges it over the shared `settings.json`).

## Install on a fresh machine

```sh
git clone https://github.com/weatherwolf/setup.git ~/setup
cd ~/setup
./bootstrap.sh      # clones powerlevel10k, then runs install.sh
```

Or, if powerlevel10k is already present, just:

```sh
./install.sh
```

`install.sh` is re-runnable. Any existing real file or directory is backed up
to `<path>.bak.<timestamp>` before a symlink replaces it; stale symlinks are
replaced in place.

## Machine-specific overrides

Anything that should differ per machine (work-only aliases, env vars, paths)
goes in `~/.zshrc.local`, which is sourced at the end of `.zshrc` and is never
tracked.

## Not tracked here

- **powerlevel10k** - third-party theme, cloned from upstream by `bootstrap.sh`.
- **nvim plugin/runtime data** - lives under `~/.local/share/nvim`,
  `~/.local/state/nvim`, `~/.cache/nvim`.
- **Secrets / credentials** - e.g. `gh` auth (`~/.config/gh`). Run
  `gh auth login` per machine.
- **`~/.gitconfig`** - identity/credential settings, kept machine-local.
