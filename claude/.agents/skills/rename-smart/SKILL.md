---
name: rename-smart
description: Generate a concise, searchable title for the CURRENT conversation based on what it is mainly about, and apply it as the session name (so it is easy to find later in /resume). Use before /clear, or any time the user asks to rename or retitle the current session.
---

# rename-smart

Give the current conversation a short, searchable title and apply it to the live session.

## Steps

1. Decide the title from what THIS conversation is actually about -- the real work
   the user came for, not this renaming step. Make it:
   - 3 to 6 words
   - lowercase, hyphen-separated (a slug)
   - ASCII letters, numbers, and hyphens only
   - built from the concrete keywords someone would later search for (feature,
     component, bug, subsystem) -- no dates, no filler like "help", "session",
     "conversation", "task".

   Examples: `auth-token-refresh-bug`, `stripe-webhook-retries`,
   `rename-on-clear-hook-skill`.

2. Apply it by running the shared helper (no session id needed -- it auto-detects
   the current session by working directory and appends a durable custom-title
   record to the transcript, the same thing /rename does):

   ```bash
   ~/.claude/hooks/set-custom-title.sh "<your-slug>"
   ```

3. Confirm to the user: state the new name, and note they can also run
   `/rename <your-slug>` themselves if they want to set it through the built-in
   command. If the helper reported an error, show it and fall back to suggesting
   the `/rename <your-slug>` command.

## Notes

- This renames the CURRENT live session only (same effect as the built-in
  `/rename`). The helper edits `~/.claude/sessions/<pid>.json` directly; that file
  layout is internal to Claude Code and could change on an update, so if the
  helper stops working, fall back to telling the user the slug to type after
  `/rename`.
- Renaming does NOT survive `/clear` (Claude Code discards the session file on
  clear). To find a conversation AFTER clearing it, use the `find-convo` skill,
  which searches the durable index that the `rename-on-clear` hook writes at
  clear time.
