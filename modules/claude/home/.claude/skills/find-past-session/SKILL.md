---
name: find-past-session
description: Use when Anand says "we did this before", "remember when", "find the session where", asks what was decided earlier, or before you say something never happened or was never discussed. Searches past session transcripts.
---

# Find past session

Never say "we never did that" or "no record" from memory. Search first.

## Search
1. Write three phrasings of what you are looking for: his likely words (Hinglish too), the technical terms, and a distinctive name, file or command.
2. Run `~/.claude/skills/find-past-session/search.sh "<phrase 1>" "<phrase 2>" "<phrase 3>"`. It prints `session  date  matching text`, at most 30 lines.
3. Ignore hits from the current session. If the hits are noisy, narrow the phrases and run again.
4. Read the matching transcript lines that matter (`~/.claude/projects/*/<session>.jsonl`) before quoting them.

## Answer
- Found: the session id, the date, and his or your exact words quoted. Resume with `claude --resume <session>` if he wants to continue it.
- Not found after three phrasings: say "not found in transcripts", list the phrases tried, and note transcripts older than the history window are gone.
- Also check the auto-memory `MEMORY.md` and `DECISIONS.md` for the project.
