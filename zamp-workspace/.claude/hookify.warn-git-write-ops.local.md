---
name: warn-git-write-ops
enabled: true
event: bash
pattern: git\s+(commit|push|add\s+-A|add\s+-u|cherry-pick|rebase|reset|merge)
---

**Git write operation detected.** Before proceeding, confirm:

1. **Which worktree am I in?** — `pwd` should match the intended repo/branch.
2. **Which branch is active?** — Run `git branch --show-current` if unsure.
3. **Is this the right branch?** — The session has multiple active worktrees (`pantheon`, `pantheon-stripe`, `pantheon-billing-enforcement`, `application-platform-frontend`). A Bash shell does NOT persist `cd` between calls — verify explicitly.

If the current directory or branch is not the intended target, stop and navigate first.
