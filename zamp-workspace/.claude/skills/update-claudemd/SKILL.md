---
name: update-claudemd
description: User-invocable as /update-claudemd. Scan the current session and recent auto-memory entries, propose diffs to /home/coder/zamp/.claude/CLAUDE.md (the workflow doc), and apply approved changes. Use at end-of-session or after any conversation where workflow expectations got clarified.
disable-model-invocation: true
---

# /update-claudemd — keep the workflow doc current

This skill maintains `/home/coder/zamp/.claude/CLAUDE.md` — the co-owned workflow doc. It does NOT touch atomic memory (`~/.claude/projects/.../memory/`), and it does NOT touch any other CLAUDE.md (repo-shipped or otherwise).

## What this skill is for

The workflow doc captures **how Anand and Claude work together** — phase discipline, tool routing, anti-patterns, repo gates. It evolves as we discover new preferences, corrections, or rituals during real sessions.

## What this skill is NOT for

- **Not for atomic facts** (e.g. "user prefers tabs over spaces"). Those go in auto-memory via the built-in `feedback`/`user`/`project` types — the system prompt mandates saving them.
- **Not for repo-shipped CLAUDE.md** (e.g. `services/pantheon/CLAUDE.md`). That's the company's. If something there is wrong, raise it as a separate question.
- **Not for system-level `~/.claude/`**. Hands off.

## Method

1. **Scan**: re-read the current session transcript. Identify:
   - explicit corrections from the user ("don't do X", "always do Y")
   - quiet validations (user accepted an unusual choice without pushback — that choice should become a rule)
   - new tool/skill/agent usage that should be documented in the routing table
   - new anti-patterns discovered ("we tripped on X again")
2. **Cross-check** with recent auto-memory: list `~/.claude/projects/-home-coder-zamp/memory/*.md` and skim. If a pattern there is now load-bearing for the workflow, promote it into CLAUDE.md (and leave the atomic memory alone — they serve different purposes).
3. **Optionally invoke** `hookify:conversation-analyzer` if the session was long or contained multiple corrections — it's the dedicated tool for this.
4. **Optionally invoke** `claude-md-management:claude-md-improver` for the actual edit — it knows the structural conventions for CLAUDE.md files. Point it at `/home/coder/zamp/.claude/CLAUDE.md`.
5. **Propose diffs**, one section at a time. For each:
   - quote the proposed change
   - cite the conversation evidence (turn ID, quote)
   - ask the user to approve / reject / refine
6. **Apply approved diffs** with `Edit`. Keep the doc concise — if a section grows past ~30 lines, consider splitting it into a referenced skill/agent.

## Scope of edits

- Add to existing sections; don't restructure unless the user asks.
- Trim stale entries: if an anti-pattern is no longer applicable (e.g. tool migrated), remove it.
- Keep the **Maintenance** section at the bottom up to date when paths change.

## Anti-loop guard

If the user keeps re-stating the same rule across sessions, the rule is too soft. Promote it:

- to a hook (via `hookify:writing-rules`) for things that should fail-fast
- to a skill if it needs context
- to an agent if it needs a review pass

Don't just keep adding bullet points to CLAUDE.md.

## Output

Diff blocks ready to apply, one per section, plus rationale. The user approves; you apply with `Edit`. Show the final file size at the end.
