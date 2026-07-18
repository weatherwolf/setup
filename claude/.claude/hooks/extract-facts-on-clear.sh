#!/usr/bin/env bash
# extract-facts-on-clear.sh -- Claude Code SessionEnd hook (matcher: "clear")
#
# When a conversation is cleared with /clear, extract durable project facts
# from the transcript (corrections, commands, conventions, gotchas) that are
# not already covered by the project's CLAUDE.md, and stage them as proposals
# in ~/.claude/pending-facts/<cwd-hash>.md.
#
# Nothing is ever written to CLAUDE.md by this script. The companion
# SessionStart hook (propose-facts-on-start.sh) injects instructions into the
# next session so Claude presents the proposals for interactive approval.
#
# Skips quietly when: the cwd has no CLAUDE.md, the transcript is missing or
# too short, or the model finds nothing new (outputs NONE).
#
# A marker file <cwd-hash>.extracting exists while the model call runs, so the
# SessionStart hook knows proposals may still be on the way.
#
# Receives the hook payload as JSON on stdin (session_id, transcript_path, cwd).
# Best-effort: always exits 0 so it can never block or error out /clear.
# Diagnostics go to ~/.claude/claudemd-facts.log.
set -uo pipefail

LOG="${HOME}/.claude/claudemd-facts.log"
PENDING_DIR="${HOME}/.claude/pending-facts"
log() { printf '%s %s\n' "$(date -Iseconds 2>/dev/null || echo now)" "$*" >> "$LOG"; }

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"

if [ -z "$cwd" ] || [ ! -f "$cwd/CLAUDE.md" ]; then
  log "skip: no CLAUDE.md in cwd (cwd=$cwd session=$session_id)"
  exit 0
fi

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  log "skip: no transcript (session=$session_id)"
  exit 0
fi

# Flatten the transcript to plain text (user + assistant turns only). Facts
# and corrections tend to appear late, so keep the tail.
convo="$(jq -rs '
  [ .[]
    | select(.type == "user" or .type == "assistant")
    | .message.content
    | if type == "string" then .
      elif type == "array" then ([ .[] | select(.type == "text") | .text ] | join(" "))
      else empty end
  ] | join("\n")
' "$transcript" 2>/dev/null | tail -c 40000)"

if [ "${#convo}" -lt 200 ]; then
  log "skip: transcript too short (session=$session_id)"
  exit 0
fi

mkdir -p "$PENDING_DIR"
hash="$(printf '%s' "$cwd" | md5sum | awk '{print $1}')"
pending="$PENDING_DIR/$hash.md"
marker="$PENDING_DIR/$hash.extracting"

touch "$marker"
trap 'rm -f "$marker"' EXIT

claudemd="$(head -c 12000 "$cwd/CLAUDE.md" 2>/dev/null)"
already_pending="$(head -c 6000 "$pending" 2>/dev/null || true)"

read -r -d '' prompt <<EOF || true
You maintain a project's CLAUDE.md file: persistent instructions loaded into
every future Claude Code session in that project. Below are (1) the current
CLAUDE.md, (2) facts already proposed but not yet reviewed, and (3) the tail
of a conversation transcript that just ended.

Extract at most 6 DURABLE, PROJECT-LEVEL facts from the transcript that a
future session would get wrong without. Good candidates: corrections the user
gave, non-obvious commands that worked, conventions, required env vars,
gotchas. Exclude: anything already covered in (1) or (2), session-specific
work ("we fixed bug X"), anything derivable by reading the repo, and generic
advice. Treat (2) as strict: if a candidate fact is semantically equivalent
to any bullet in (2), even with different wording, do NOT output it.

Output format: one markdown bullet per fact, each starting with "- ", one
line each, ASCII only. If nothing qualifies, output exactly: NONE
Output ONLY the bullets or NONE. No preamble, no headings.

=== (1) CURRENT CLAUDE.md ===
$claudemd

=== (2) ALREADY PROPOSED ===
$already_pending

=== (3) TRANSCRIPT ===
$convo
EOF

raw="$(claude -p --model claude-sonnet-5 "$prompt" 2>>"$LOG")"

facts="$(printf '%s\n' "$raw" | grep -E '^- ' || true)"

# Mechanical backstop: drop bullets that already exist verbatim in the
# pending file or in CLAUDE.md itself.
if [ -n "$facts" ] && [ -f "$pending" ]; then
  facts="$(printf '%s\n' "$facts" | grep -Fxv -f <(grep -E '^- ' "$pending" 2>/dev/null) || true)"
fi
if [ -n "$facts" ]; then
  facts="$(printf '%s\n' "$facts" | grep -Fxv -f <(grep -E '^- ' "$cwd/CLAUDE.md" 2>/dev/null) || true)"
fi

if [ -z "$facts" ] || printf '%s' "$raw" | head -n1 | grep -qx 'NONE'; then
  log "skip: nothing new (session=$session_id cwd=$cwd)"
  exit 0
fi

if [ ! -f "$pending" ]; then
  printf '# Proposed CLAUDE.md additions for %s\n' "$cwd" > "$pending"
fi
{
  printf '\n## From session %s (%s)\n' "${session_id:-unknown}" "$(date -Iseconds 2>/dev/null || echo now)"
  printf '%s\n' "$facts"
} >> "$pending"

log "ok: staged $(printf '%s\n' "$facts" | wc -l) fact(s) -> $pending (session=$session_id)"
exit 0
