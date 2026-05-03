---
name: Never push to remote without explicit permission
description: User must explicitly confirm before any git push. Applies to plain pushes, force pushes, and any workflow (PR creation, skills) that would push under the hood.
type: feedback
originSessionId: bda7d3d5-57f1-4c30-91a2-8087dc2fc6e0
---
Never run `git push` (any flavor — plain, `--force`, `-u`, branch pushes) or any command/skill that pushes to remote without an explicit user instruction or confirmation in the current turn. Same applies to `gh pr create` and similar commands that implicitly push the local branch.

**Why:** User wants every push to be a deliberate, conscious act. They want to review the local state (commits, branch, what's about to land on the remote) before anything leaves their machine. Stated explicitly when cleaning up settings.json: "I never want it to push to remote without my permission."

**How to apply:**
- Do not put `Bash(git push *)` in any allow list. The prompt itself is the safety net.
- Even when a higher-level workflow (e.g. the `pr-workflow` skill, a "create PR" request, a commit-and-push compound request) would push, pause and confirm: state what you're about to push, what branch, what remote, and ask before running it.
- "Commit this" does NOT imply "push this". Commit, then ask.
- "Create a PR" — the push is the riskier half; confirm the push before running, even if PR creation was the user's ask.
- Force pushes to `main`/`master` are already denied at settings.json level; this rule is the broader behavioral version that covers all branches and all push-equivalents.
