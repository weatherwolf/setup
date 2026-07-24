#!/usr/bin/env bash
# propose-facts-on-start.sh -- Claude Code SessionStart hook (matcher: "clear")
#
# Companion to extract-facts-on-clear.sh. When a fresh session starts after
# /clear, check whether that script staged (or is still staging) proposed
# CLAUDE.md additions for this cwd. If so, inject instructions telling Claude
# to present them for interactive approval on the user's first message, write
# the approved ones into ./CLAUDE.md, and delete the pending file.
#
# The extraction runs concurrently with session start (a model call takes
# seconds), so this checks both the finished pending file and the in-progress
# marker; the actual file read happens at first-message time, when extraction
# has long finished.
#
# Emits {"hookSpecificOutput":{"hookEventName":"SessionStart",
# "additionalContext":...}} on stdout, or nothing when there is nothing
# pending. Best-effort: always exits 0.
set -uo pipefail

PENDING_DIR="${HOME}/.claude/pending-facts"

input="$(cat)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || exit 0

# Portable md5: coreutils md5sum on Linux, BSD md5 on macOS. Must match the
# hash computed in extract-facts-on-clear.sh so the two hooks agree on the path.
if command -v md5sum >/dev/null 2>&1; then
  hash="$(printf '%s' "$cwd" | md5sum | awk '{print $1}')"
else
  hash="$(printf '%s' "$cwd" | md5 -q)"
fi
pending="$PENDING_DIR/$hash.md"
marker="$PENDING_DIR/$hash.extracting"

emit=0
if [ -s "$pending" ]; then
  emit=1
elif [ -f "$marker" ]; then
  now="$(date +%s)"
  mtime="$(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null || echo 0)"
  if [ $(( now - mtime )) -lt 180 ]; then
    emit=1
  fi
fi
[ "$emit" -eq 1 ] || exit 0

read -r -d '' ctx <<EOF || true
The previous conversation in this directory was cleared, and a hook staged
proposed additions to this project's CLAUDE.md at:
  $pending
At the start of your FIRST reply in this session, before addressing anything
else: read that file. If it exists and contains fact bullets, present them to
the user with AskUserQuestion (multiSelect, one option per fact, so the user
picks which to keep). Append the approved facts to ./CLAUDE.md in the most
fitting existing section (or a sensible new one), then delete the pending
file. If the file does not exist or has no bullets, say nothing about any of
this and just answer the user normally.
EOF

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
