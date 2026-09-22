# setup

My Linux dotfiles, managed as a single Git repo. Configs are kept at their
default paths via symlinks back into this repo, so editing a file through its
normal location (e.g. `~/.zshrc`) edits the tracked file here.

## Purpose (read this first)

This repo is the single source of truth for a reproducible dev environment
(zsh + starship, tmux, herdr, Neovim, and Claude Code). Cloning it and running
`./bootstrap.sh` on a fresh machine reinstalls the tools and re-creates the
symlinks, reproducing the environment. The guiding rule: anything you'd want to
survive a machine wipe is tracked here and symlinked into place; machine- or
secret-specific bits are deliberately left untracked (see the last section).

For agents working in this repo: prefer editing files through the repo (they
are symlinked to their live locations), keep `install.sh`/`bootstrap.sh`
re-runnable and idempotent, and never commit secrets or machine-local state.

## Layout

The repo uses a Stow-compatible package layout (each top-level dir mirrors
`$HOME`), but installation uses a plain script with no dependencies.

```
zsh/.zshrc                    -> ~/.zshrc
starship/.config/starship.toml  -> ~/.config/starship.toml
tmux/.tmux.conf               -> ~/.tmux.conf
herdr/.config/herdr/config.toml -> ~/.config/herdr/config.toml
nvim/.config/nvim             -> ~/.config/nvim
claude/.claude/CLAUDE.md      -> ~/.claude/CLAUDE.md
claude/.claude/settings.json  -> ~/.claude/settings.json
claude/.claude/statusline.py  -> ~/.claude/statusline.py
claude/.claude/hooks          -> ~/.claude/hooks           (directory)
claude/.agents/.skill-lock.json -> ~/.agents/.skill-lock.json
```

`hooks/` is symlinked as a whole directory, so any hook you add later is
tracked automatically. A hook also needs an entry under `"hooks"` in
`settings.json` (tracked) to actually run.

Machine-specific Claude overrides go in `~/.claude/settings.local.json`
(untracked; Claude merges it over the shared `settings.json`).

## Git hooks

`githooks/` holds the repo's own git hooks; `install.sh` points
`core.hooksPath` at it. `pre-commit` swaps the tree to the `glacier-wave`
palette (via `update_palette.sh`) and stages the files it touched, so commits
never carry whatever palette happens to be live. `post-commit` swaps the live
palette back. Note that a file the swap touches is staged whole, so partially
staged hunks in it go along.

## Claude Code skills

Skills are managed by the `skills` CLI (`npx skills`), not vendored here. The
skill content lives in `~/.agents/skills/` and is symlinked into
`~/.claude/skills/` by the tool, so `~/.claude/skills` is deliberately NOT a
repo symlink and is not tracked.

What IS tracked is the manifest, `~/.agents/.skill-lock.json` (symlinked into
this repo). It records exactly which skills are installed and from where
(currently from `mattpocock/skills` and `vercel-labs/skills`). This is the
recipe, not the content:

- **Which skills you use is tracked.** Every `skills add` / `remove` / `update`
  rewrites the lockfile, so `git -C ~/setup status` shows when your skill set
  changed. Commit the lockfile diff to record it.
- **Upstream updates keep working.** `npx skills update -g` pulls new versions;
  the repo isn't frozen on a committed copy.
- **A fresh machine reproduces them with no manual picking.** `bootstrap.sh`
  parses the lockfile and re-adds each source with its exact skill list
  (`npx skills add <source> -g -y -s <skills>`), so only the recorded skills are
  installed. (The CLI's `experimental_install` only restores project-level
  lockfiles, not this global one.)

If you ever need to hand-edit a skill and keep the edit, that would require
vendoring the content instead; this repo intentionally does not, to preserve
`skills update`.

The exception is skills the lockfile cannot reproduce: hand-made local ones
that were never installed via the CLI (`find-convo`, `rename-smart`) and ones
whose upstream repo deleted them, so `skills add` can no longer fetch them
(`decision-mapping`, `to-issues`, `to-prd`, removed from mattpocock/skills).
Their content IS vendored, under `claude/.agents/skills/`, and `install.sh`
symlinks each one into both `~/.agents/skills/` and `~/.claude/skills/`.
Project-level skills (for example `.claude/skills/` inside a project repo) are
tracked by that project's own git, not here.

## Install on a fresh machine

```sh
git clone https://github.com/weatherwolf/setup.git ~/setup
cd ~/setup
./bootstrap.sh      # installs starship and the other tools, then runs install.sh
```

Or, if the tools are already present, just:

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

- **starship** - third-party prompt binary, installed by `bootstrap.sh` (brew on
  macOS, the official installer elsewhere); only its config
  (`starship/.config/starship.toml`) is tracked. `.zshrc` initializes it only if
  the binary is on PATH, so a machine without it falls back to zsh's default
  prompt instead of erroring.
- **herdr** - third-party multiplexer binary, installed from herdr.dev by
  `bootstrap.sh`; only its config (`herdr/.config/herdr/config.toml`) is tracked.
  herdr runs alongside tmux and its config mirrors the tmux setup (prefix C-a,
  vim pane nav, `|`/`-` splits, dark theme + green accent, server-based session
  persistence in place of resurrect/continuum). The three tmux features with no
  herdr equivalent are listed in the NOTES block at the bottom of the config.
- **Skill content** (`~/.agents/skills/`, `~/.claude/skills/`) - reinstalled
  from the tracked `.skill-lock.json` by `bootstrap.sh`; only the manifest is
  tracked. See "Claude Code skills" above.
- **nvim plugin/runtime data** - lives under `~/.local/share/nvim`,
  `~/.local/state/nvim`, `~/.cache/nvim`.
- **Secrets / credentials** - e.g. `gh` auth (`~/.config/gh`). Run
  `gh auth login` per machine.
- **`~/.gitconfig`** - identity/credential settings, kept machine-local.
