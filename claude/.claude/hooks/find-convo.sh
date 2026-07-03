#!/usr/bin/env bash
# find-convo.sh [keyword ...]
#
# Search the durable conversation index written by the rename-on-clear hook and
# print matching past conversations, newest first, each with a ready-to-run
# resume command. With no keyword, lists everything.
#
# Index format (TSV): epoch <TAB> iso-time <TAB> title <TAB> sessionId <TAB> cwd <TAB> transcript
set -uo pipefail

INDEX="${HOME}/.claude/conversation-index.tsv"
if [ ! -s "$INDEX" ]; then
  echo "No conversation index yet ($INDEX is empty)."
  echo "It fills up as you /clear conversations (the rename-on-clear hook writes to it)."
  exit 0
fi

query="$*"

# Newest first; filter by ANDing all keywords (case-insensitive) against the row.
sort -t"$(printf '\t')" -k1,1nr "$INDEX" | awk -F'\t' -v q="$query" '
  BEGIN { n = split(tolower(q), terms, /[ ]+/) }
  {
    if (q != "") {
      hay = tolower($0)
      for (i = 1; i <= n; i++) {
        if (terms[i] != "" && index(hay, terms[i]) == 0) next
      }
    }
    printf "%-28s  %s\n", $3, $2
    printf "    resume:  claude --resume %s\n", $4
    printf "    cwd:     %s\n\n", $5
    matched++
  }
  END {
    if (matched == 0) print "No conversations matched: " q
  }
'
