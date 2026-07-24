#!/usr/bin/env bash
# set-custom-title.sh <title> <session_id> <transcript_path>
#
# Durably titles a Claude Code conversation by appending the two title records
# that /resume reads (and that survive /clear) to the session transcript:
#   {"type":"custom-title","customTitle":"<title>","sessionId":"<id>"}
#   {"type":"agent-name","agentName":"<title>","sessionId":"<id>"}
# This mirrors the records Claude Code writes natively for /rename. Called by
# rename-on-clear.sh, which captures stdout and logs it. Prints a one-line
# summary and exits 0 on success; prints an error and exits non-zero otherwise.
set -uo pipefail

title="${1:-}"
session_id="${2:-}"
transcript="${3:-}"

if [ -z "$title" ] || [ -z "$session_id" ] || [ -z "$transcript" ]; then
  echo "usage: set-custom-title.sh <title> <session_id> <transcript_path>" >&2
  exit 1
fi
if [ ! -f "$transcript" ] || [ ! -w "$transcript" ]; then
  echo "transcript missing or not writable: $transcript" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; cannot write title records" >&2
  exit 1
fi

# Build both records with jq so the title/id are correctly JSON-escaped. jq -c
# emits each top-level object on its own line, giving valid JSONL.
if ! records="$(jq -cn --arg t "$title" --arg s "$session_id" \
      '{type:"custom-title", customTitle:$t, sessionId:$s},
       {type:"agent-name",   agentName:$t,  sessionId:$s}')"; then
  echo "failed to build title records" >&2
  exit 1
fi

if ! printf '%s\n' "$records" >> "$transcript"; then
  echo "failed to append title records to $transcript" >&2
  exit 1
fi

echo "titled session $session_id -> '$title'"
exit 0
