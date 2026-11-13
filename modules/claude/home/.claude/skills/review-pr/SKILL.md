---
name: review-pr
description: Use when Anand asks to review a colleague's pull request, gives a PR link or number to review, or asks what to comment on a PR.
---

# Review PR

Reviewing makes the PR his (`rules/building.md`, Reviews). Judge it as code he will answer for. Block only for the blocking classes in the severity scale; do not hold the PR to perfection.

The review itself is `~/.claude/review/run.md`, in mode `colleague`. This skill fetches the PR, runs it, and turns the result into a report and a ledger.

Copy this checklist and tick it as you go:

```
- [ ] 1 triage   - [ ] 2 run   - [ ] 3 report   - [ ] 4 ledger   - [ ] 5 clean up
```

## 1. Triage
- `gh pr view <n> --json state,isDraft,title,body,baseRefName,baseRefOid,headRefOid,isCrossRepository,changedFiles`. Stop if it is closed or merged.
- `git fetch origin pull/<n>/head` (works for forks) into the local clone, or into a blobless clone in the scratchpad (`git clone --filter=blob:none`). Confirm the fetched commit is `headRefOid`.
- `merge_base = git merge-base <baseRefOid> <headRefOid>`. List files with `git diff --numstat <merge_base> <headRefOid>`; its count must equal `changedFiles`.
- Classify each file: source; migration; infra and CI (CI workflows, IaC, container and deploy manifests, access policies); test or `qa/` (read for intent only); docs and config; manifest or lockfile; generated; vendored; snapshot; binary. If nothing reviewable remains, report CI and coverage and stop.

## 2. Run
Follow `~/.claude/review/run.md` with mode `colleague`, base `merge_base`, head `headRefOid`, id `<n>`, and the PR description as the goal. Conventions come from `baseRefOid`, the rules that apply on merge. `comments.md` holds the existing review threads with resolved state and the author's replies. `checks.md` holds CI on head.

## 3. Report
Start with CI status and the PR goal, and say first if it is a draft. Then blocking, should fix, questions, with severity as defined in `~/.claude/review/lenses.md`, Shared contract, each section ordered by harm, worst first. No praise.

Each item is at most three lines: `path:line`, what goes wrong and when, the rule broken, the fix. A question names the one fact that would decide it. Then:
- Existing comments still open: raised before, acknowledged or not, and not fixed in head.
- Pre-existing, not caused by this PR.
- Dropped: `id | verdict | reason`, one line each, so a wrong drop can be rescued.
- Coverage: lenses run, files skipped or split, areas not judged, claims probed.

## 4. Ledger
In `~/personal/reviews/<owner>-<repo>-<n>.md`, with the merge base and head commits reviewed: `| # | comment (who, path:line) | status | reply |`. Status: proposed (not posted yet), open, agreed, disputed, resolved, dropped. Add every existing comment and every kept finding. The reply column stays empty until Anand decides.

When Anand drops a finding as wrong, add one line to `~/personal/reviews/suppressions.md`: what was flagged and why it was wrong.

## 5. Clean up
Remove the `head/` worktree.

## Re-review after new pushes
Run as in step 2, with these differences:
- `diff.patch` is `git range-diff --remerge-diff <old_merge_base>..<old_head> <new_merge_base>..<new_head>`. It covers a rebase and a merge from base alike, and leaves out base changes merged in. `full.patch` is the current full PR diff, for context only.
- Lenses report only on what `diff.patch` shows changed, and the callers of what changed are in scope.
- `ledger.md` holds the open ledger items, and refuters also return `resolved`, `still open` or `disputed` for each.
- Say in the report what was not re-reviewed.

## Replies
- Discuss each comment with him. He decides.
- Draft the reply in his voice with the `voice-draft` skill.
- Never post a review, comment or reply yourself. He posts it.
