---
description: Update the current pantheon branch with main, refresh secrets, and rebuild deps.
---

Run `make sync-from-main` from `/home/coder/zamp/services/pantheon`. This rebases (or merges, depending on the Makefile target — read the actual command before running) the current branch onto `main`, runs `make sync-secrets`, and reinstalls deps if `pyproject.toml` changed.

Before running:
- Confirm working tree is clean (`git status` shows no unstaged changes), or stash first.
- Confirm the user has authorized this — the target may rewrite history.

After running:
- Surface any merge conflicts.
- Surface any new dep changes that came in from main (`poetry.lock` diff size).
- Recommend `make dev-restart` if workers are running, since deps or secrets may have changed.

Per `factual-mode`: read the make output. Don't claim a sync succeeded because exit 0 — verify with `git log --oneline origin/main..HEAD` to confirm the branch is now ahead of main.
