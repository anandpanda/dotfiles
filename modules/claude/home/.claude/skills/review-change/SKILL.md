---
name: review-change
description: /review-change reviews the change Anand names in chat, a colleague's pull request or his own PR, branch or uncommitted work.
---

# Review change

This is the Check stage of `rules/lifecycle.md`. The engine is `~/.claude/review/run.md`: readers hold every line against Anand's standard (`rules/building.md`, Principles) and the repo's written rules (`CLAUDE.md` or `AGENTS.md` and the convention and codebase guides they point to); breakers attack the running change from `~/.claude/review/areas.md`. Block only for the blocking classes in the severity scale; do not hold a change to perfection.

## 1. Pick the mode
Take what to review from what Anand says in chat; if he has not said, ask.
- A PR whose author is not Anand: mode `colleague`. Reviewing makes the PR his (`rules/building.md`, Reviews): judge it as code he will answer for.
- His own work, current branch or uncommitted changes, or a PR he authored: mode `own`.
- When the change is a stack of PRs, the scope is every PR in it unless he names fewer; state the scope in one line first. Feedback on a PR means its inline comments, review bodies and conversation comments, for every PR in the stack.

## 2. Triage
Colleague:
- `gh pr view <n> --json state,isDraft,title,body,author,baseRefName,baseRefOid,headRefOid,isCrossRepository,changedFiles`. Stop if it is closed or merged.
- `git fetch origin pull/<n>/head` (works for forks) into the local clone, or into a blobless clone in the scratchpad (`git clone --filter=blob:none`). Confirm the fetched commit is `headRefOid`.
- `merge_base = git merge-base <baseRefOid> <headRefOid>`. List files with `git diff --numstat <merge_base> <headRefOid>`; its count must equal `changedFiles`.

Own:
- Base is `git merge-base <default branch> HEAD`. Head is `HEAD`; when the tree has uncommitted changes, the working tree itself is `head/` and `diff.patch` is `git diff <base>`.
- The goal is the task and its acceptance criteria from this session, or the PR description.
- `checks.md`: run the tests for what changed and the linter first, and record the results.

Both: classify each file: source; migration; infra and CI (CI workflows, IaC, container and deploy manifests, access policies); test or `qa/`; docs and config; manifest or lockfile; generated; vendored; snapshot; binary. If nothing reviewable remains, report CI and coverage and stop.

## 3. Run
Follow `~/.claude/review/run.md` with the mode, base and head above. Colleague: conventions come from `baseRefOid`, `comments.md` holds the existing review threads with resolved state and the author's replies, and `checks.md` holds CI on head.

Find the review stack from the repo's own docs (`run.md`) and bring it up on head the way they say; breakers start once the change runs there. With no stack named, say so in the report: readers stay read-only and breakers run what they can in-process.

## 4. Report
Start with CI or check status and the goal; say first if a PR is a draft. Then blocking, should fix, questions, with severity as defined in `~/.claude/review/lenses.md`, Shared contract, each section ordered by harm, worst first: security, then data, then users, then code health. No praise.

Each item is at most three lines: `path:line`, what goes wrong and when, the rule broken, the fix. A question names the one fact that would decide it. Then: existing comments still open (colleague), pre-existing problems, Dropped (`id | verdict | reason`, one line each), Coverage (lenses run, coverage-map gaps, breaker surface maps and areas attacked, files skipped or split, areas not judged, claims probed). Own mode adds the clusters from `findings/clusters.md`: each cause, its findings, and the design-level fix at its owner.

Own mode is the Check loop, and the report is the loop sync. Repeat until a round finds nothing worth fixing, minor items included:
1. Split into parts and seams; a reader and a breaker each. Full coverage: every hunk against every lens, every surface on some breaker's map. Neutral prompts: a part or an area and a mindset, never the expected answers.
2. Refute every finding with a fresh agent; only survivors count.
3. Cluster survivors by root cause, not by file.
4. Fix each cluster at the design level, once, at its owner. A guard, flag, special case or second home for one decision is a workaround: fix it properly, or bring it to Anand named as a workaround. A fix that changes the agreed design goes to him first.
5. Every fix starts as a failing test that reproduces the finding.
6. Then another round only on the parts and seams still producing real findings. The loop ends when a round is quiet and every map is complete.

## Learn
After the PR is up, for each comment a reviewer or bot leaves: say why it escaped and propose the line it suggests for the standard, `lenses.md` or `areas.md`. Add a line only on Anand's go, with the comment as its source.

## 5. Ledger (colleague)
In `~/personal/reviews/<owner>-<repo>-<n>.md`, with the merge base and head reviewed: `| # | comment (who, path:line) | status | reply |`. Status: proposed (not posted yet), open, agreed, disputed, resolved, dropped. Add every existing comment and every kept finding. The reply column stays empty until Anand decides. When he drops a finding as wrong, add one line to `~/personal/reviews/suppressions.md`: what was flagged and why it was wrong.

## 6. Clean up
Remove the `head/` worktree.

## Re-review after new pushes
Run as in step 3, with these differences:
- `diff.patch` is `git range-diff --remerge-diff <old_merge_base>..<old_head> <new_merge_base>..<new_head>`: a rebase and a merge from base alike, without base changes merged in. `full.patch` is the current full diff, for context only.
- Lenses report only on what `diff.patch` shows changed, and the callers of what changed are in scope.
- `ledger.md` holds the open ledger items; refuters also return `resolved`, `still open` or `disputed` for each.
- Say in the report what was not re-reviewed.

## Replies
- Discuss each comment with him. He decides.
- Draft the reply in his voice with the `voice-draft` skill.
- Never post a review, comment or reply yourself. He posts it.
