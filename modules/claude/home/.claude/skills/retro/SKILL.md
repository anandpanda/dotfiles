---
name: retro
description: Use when Anand runs /retro to review one session and improve the Claude Code harness. Reads the session (the current one by default, or one he names) and proposes rule, permission, skill, agent and plugin changes for him to pick.
argument-hint: "[session-id or transcript path]"
disable-model-invocation: true
---

# Retro

One session in, harness proposals out. Edit nothing and commit nothing until Anand picks.

## 1. Read the session
- `~/.claude/skills/retro/pairs.sh [transcript]` prints the conversation as JSON lines `{role, ts, text}`. With no argument it uses the newest transcript for the current directory, which is this session. For a session id, pass `~/.claude/projects/*/<id>.jsonl`.
- Read it all. Mark each place where he corrected, repeated, pushed back, re-asked, or where work was redone.

## 2. Read the harness
`~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, `~/.claude/skills/*/SKILL.md`, `~/.claude/agents/*.md`, the permission rules and `enabledPlugins` in `~/.claude/settings.json`. In the dotfiles repo, `modules/claude/RESOLVER.md` says which file owns each rule.

## 3. Diagnose
For each marked moment: what went wrong, his exact words, and the cause: a rule missing, a rule unclear, a rule present but ignored, a missing guard rail, a missing skill, or a one-off. One-offs get no proposal.

## 4. Research
Have the `researcher` agent cite current docs for every plugin or Claude Code feature you suggest, with a checked link and the version it needs. Give it a findings file.

## 5. Propose
Group the proposals, each with the evidence (session line), the exact change (file and text), and why:
1. **rule add / update / delete** (prefer update or delete over add; respect the 200-line cap on CLAUDE.md plus rules);
2. **permission rule** (ask or deny, as in `settings.owned.json`);
3. **skill or agent**;
4. **plugin or feature**, with the doc link.

Number every proposal so he can pick by number. Then stop. Apply only the numbers he picks, through the dotfiles repo so git carries them to every machine.
