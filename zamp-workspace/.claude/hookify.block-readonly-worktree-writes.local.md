---
name: block-readonly-worktree-writes
enabled: true
event: bash
pattern: (pantheon-pr\d+|pantheon-old-acu|pantheon-old-billing|application-platform-frontend-pr\d+|application-platform-frontend-old-billing|pantheon-invoices|pantheon-pricing-v1)
---

**Read-only reference worktree detected in the command path.**

The directories matching `pantheon-pr*`, `pantheon-old-*`, `application-platform-frontend-pr*`, and similar reference worktrees are **read-only**. They exist only for reference (diffing, cherry-picking FROM them) — do NOT commit, write files, or modify git history inside them.

**Rule:** Only write to the primary working worktrees:
- `/home/coder/zamp/services/pantheon` (`feat/billing-details`)
- `/home/coder/zamp/services/application-platform-frontend` (`feat/billing-details`)
- Named feature worktrees you explicitly created this session

If you need code from a reference branch, cherry-pick or copy to the primary worktree.
