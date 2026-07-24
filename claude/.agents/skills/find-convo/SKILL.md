---
name: find-convo
description: Search past conversations by keyword and get a command to resume the right one. Titles come from the durable index that the rename-on-clear hook writes each time a conversation is cleared. Use when the user asks to find, search for, or reopen an earlier conversation.
---

# find-convo

Find an earlier conversation by what it was about, and hand the user the command
to reopen it.

## Steps

1. Take the user's keyword(s) (a topic, feature, bug, or subsystem). If they gave
   none, list everything.

2. Run the search helper:

   ```bash
   ~/.claude/hooks/find-convo.sh <keywords>
   ```

   It prints matches newest-first, each with a `claude --resume <sessionId>`
   command and the working directory it happened in.

3. Show the user the matches. If one clearly fits, point them at its resume
   command; if several match, list the titles so they can pick. If nothing
   matched, say so and suggest broader keywords.

## Notes

- The index is `~/.claude/conversation-index.tsv`, written by the
  `rename-on-clear` SessionEnd hook. Entries appear only for conversations that
  have been `/clear`ed since the hook was installed.
- Titles are short searchable slugs (e.g. `stripe-webhook-retries`) generated
  from each conversation's content at clear time.
