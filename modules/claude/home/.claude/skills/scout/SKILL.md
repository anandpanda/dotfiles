---
name: scout
description: /scout looks for new Claude Code features, plugins, skills, agents and workflows from the recent window, and reports the ones that fit Anand's harness, each with a verdict.
argument-hint: "[window, default 30 days]"
disable-model-invocation: true
---

# Scout

Look outward for what would make this harness better. Edit nothing and commit nothing until Anand picks.

## 1. Read the installed harness
`~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`, `~/.claude/skills/*/SKILL.md`, `~/.claude/agents/*.md`, the permission rules and `enabledPlugins` in `~/.claude/settings.json`. Know what is already installed before searching, so nothing already installed is reported.

## 2. Research by kind of source
Window: the last 30 days, or the window given as the argument ($ARGUMENTS). Dispatch the `researcher` agent, one per kind or in parallel, each with the window, the harness summary and a findings file in the session scratchpad directory. The agent discovers the specific places; the starting points are examples, not a list.
- **official**: Claude Code changelog and docs, always.
- **marketplaces**: starting from the official plugin marketplace.
- **trending code**: starting from GitHub trending.
- **discussion**: starting from Hacker News and Reddit.
- **practitioners**: engineering blogs and newsletters.

## 3. Read before judging
For each candidate, read its README or code. The buzz (stars, upvotes, posts) goes next to the substance: what it really does, overlap with what he has, maintenance (last commit, open issues). An adoption must replace something or earn its place (`rules/anand.md`: simple first).

## 4. Report
One table:

| what | why it fits Anand | buzz | substance | cost | adopt / try / skip | link |

- Open every link before listing it.
- End with where the agents looked and what they could not reach.
- Number the rows. Apply only the rows he picks, through the dotfiles repo.
