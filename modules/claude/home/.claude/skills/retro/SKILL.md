---
name: retro
description: /retro reviews one or more sessions (the current one by default, or named ones) and proposes rule, permission, skill, agent and plugin changes to the Claude Code harness for Anand to pick.
argument-hint: "[session-id or transcript path ...]"
disable-model-invocation: true
---

# Retro

Sessions in, harness proposals out. Edit nothing and commit nothing until Anand picks. Each session runs steps 1 to 3 on its own, in `retro/<session-id>/` in the session scratchpad; no step looks across sessions.

## 1. Extract
- `${CLAUDE_SKILL_DIR}/pairs.sh <session-id or transcript> > pairs.jsonl`. This session: `${CLAUDE_SKILL_DIR}/pairs.sh ${CLAUDE_SESSION_ID}`. Given an id, it reads the newest copy, since a resumed session can exist in several project folders.
- Each line is `{i, role, kind, ts, text, tools?}`: his prompts and mid-turn messages, rejections with his reason, stopped calls, question answers, interrupts, slash commands, and each Claude turn as its text plus a one-line tool trail.
- A failure naming an unknown content block type means the transcript format changed: stop and report it. Never read the raw transcript instead.
- An `unreadable` entry is a torn transcript line: report it as not read.

## 2. Prepare
- `${CLAUDE_SKILL_DIR}/chunk.sh pairs.jsonl chunks` cuts it at his turns into chunks of at most 80 KB, one Read each, and prints each chunk's path with the first and last `i` it owns.
- `${CLAUDE_SKILL_DIR}/harness-then.sh <first ts> then` rebuilds the harness as it was when the session started, naming the commit taken per repo and the files no repo versions.
- `${CLAUDE_SKILL_DIR}/harness-now.sh now` copies today's harness as real files, since search tools skip the symlinks in `~/.claude`.

## 3. Read and check
- Run the Workflow tool with `scriptPath` `${CLAUDE_SKILL_DIR}/read.js`; this skill calling it is the opt-in. Pass `args: {sessions: [...]}`, one entry per session, all paths absolute: `{id, pairs, chunks: [{path, first, last}], then, now, resolver, memory_index}`. `then` and `now` are the `.claude` folders above, `resolver` is the dotfiles `modules/claude/RESOLVER.md`, and `memory_index` is the `MEMORY.md` of the session's project folder.
- It reads every chunk with a `retro-reader` and reads an unread tail again, groups each session's moments by cause within that session only, and gives each cause a fresh `reviewer`. Only its result enters this conversation.
- Check each moment's `his_words` against the `text` of its line in `pairs.jsonl` with one jq call. Drop and count any that do not match.
- Each cause comes back with one verdict:
  - **fixed since**: a rule added after the session covers it. No proposal.
  - **ignored**: a rule covered it then. Make it clearer, or a hook when it must never be broken.
  - **missing**: nothing covered it. A drafted change, kept only if it would have changed what Claude did at the cited line.
  - **one-off**: an accident, not a gap. No proposal.
- A change that contradicts an existing rule goes to Anand as a decision, never as an edit.

## 4. Propose
- Read `${CLAUDE_SKILL_DIR}/ledger.md`. Drop a proposal it shows as rejected unless this session brings new evidence, and say so.
- Prefer a hook over a rule update, and an update or delete over a new line, unless a new line is clearly the best fit.
- Group the proposals and number each, with its evidence (session and line), the exact change (file and text), its ledger action and why:
  1. **rule add / update / delete**;
  2. **permission rule** (ask or deny, as in `settings.owned.json`);
  3. **skill or agent**;
  4. **plugin or feature**: the `researcher` cites current docs for it, with a checked link and the version it needs, in a findings file in the scratchpad.
- With several sessions, list a proposal they share once and cite each session.
- Report what was not read: unreadable lines, unread chunks and tails, moments dropped for a wrong `i` or quote, unversioned files.
- Then stop. Apply only the numbers he picks, through the dotfiles repo so git carries them to every machine, and add a ledger row for every proposal shown, picked or rejected.

## Ledger
`ledger.md` lives in a public repo. Each row is a generalised learning in project-neutral words: never a quote, name, path or piece of work content.
