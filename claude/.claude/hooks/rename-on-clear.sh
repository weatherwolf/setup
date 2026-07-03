#!/usr/bin/env bash
# rename-on-clear.sh -- Claude Code SessionEnd hook (matcher: "clear")
#
# When a conversation is cleared with /clear, summarize what it was mainly about,
# durably title it, and record it in a searchable index.
#
# Titles live inside the transcript JSONL as:
#   {"type":"custom-title","customTitle":"<name>","sessionId":"<id>"}
#   {"type":"agent-name","agentName":"<name>","sessionId":"<id>"}
# which is what /resume reads and survives /clear (unlike ~/.claude/sessions/*.json).
# The index (~/.claude/conversation-index.tsv) backs the find-convo skill.
#
# NOTE: an N-messages-since-last-title gate was built and stashed at
# hooks/rename-on-clear.sh.gated.stash. This version has NO gate: it re-titles on
# every /clear. Restore the stash to re-enable the threshold.
#
# Receives the hook payload as JSON on stdin (session_id, transcript_path, cwd).
# Best-effort: always exits 0 so it can never block or error out /clear.
# Diagnostics go to ~/.claude/rename-on-clear.log.
set -uo pipefail

LOG="${HOME}/.claude/rename-on-clear.log"
INDEX="${HOME}/.claude/conversation-index.tsv"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log() { printf '%s %s\n' "$(date -Iseconds 2>/dev/null || echo now)" "$*" >> "$LOG"; }

input="$(cat)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"

if [ -z "$transcript" ] || [ ! -f "$transcript" ]; then
  log "skip: no transcript (session=$session_id)"
  exit 0
fi

# Flatten the transcript to plain text (user + assistant turns only).
convo="$(jq -rs '
  [ .[]
    | select(.type == "user" or .type == "assistant")
    | .message.content
    | if type == "string" then .
      elif type == "array" then ([ .[] | select(.type == "text") | .text ] | join(" "))
      else empty end
  ] | join("\n")
' "$transcript" 2>/dev/null | head -c 8000)"

if [ "${#convo}" -lt 40 ]; then
  log "skip: transcript too short (session=$session_id)"
  exit 0
fi

read -r -d '' prompt <<EOF || true
Read this conversation transcript and output a short, searchable title for its
MAIN topic. Rules: 3 to 6 words, lowercase, hyphen-separated, only ASCII
letters/numbers/hyphens, no dates, no filler words. Output ONLY the title.

TRANSCRIPT:
$convo
EOF

raw="$(claude -p --model claude-haiku-4-5-20251001 "$prompt" 2>>"$LOG" | head -n1)"

slug="$(printf '%s' "$raw" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c 'a-z0-9' '-' \
  | sed -E 's/-+/-/g; s/^-//; s/-$//' \
  | cut -c1-60)"

if [ -z "$slug" ]; then
  log "skip: empty slug from model (raw='$raw', session=$session_id)"
  exit 0
fi

# Durably title the cleared conversation (custom-title + agent-name records).
if title_out="$("$DIR/set-custom-title.sh" "$slug" "$session_id" "$transcript" 2>&1)"; then
  log "ok: $title_out"
else
  log "warn: custom-title failed: $title_out"
fi

# Record in the searchable index for the find-convo skill (de-dupe by session).
epoch="$(date +%s 2>/dev/null || echo 0)"
iso="$(date -Iseconds 2>/dev/null || echo unknown)"
row="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$epoch" "$iso" "$slug" "$session_id" "$cwd" "$transcript")"

touch "$INDEX"
if [ -n "$session_id" ]; then
  tmp="$(mktemp)"
  grep -v -F "	${session_id}	" "$INDEX" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$INDEX"
fi
printf '%s\n' "$row" >> "$INDEX"
log "ok: indexed session=$session_id title=$slug"

exit 0
