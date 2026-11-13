---
name: review-pr
description: Use when Anand asks to review a colleague's pull request, gives a PR link or number to review, or asks what to comment on a PR.
---

# Review PR

Reviewing makes the PR his (`rules/building.md`, Reviews). Judge it as code he will answer for. Block only for the blocking classes in the severity scale; do not hold the PR to perfection.

Copy this checklist and tick it as you go:

```
- [ ] 1 triage   - [ ] 2 bundle   - [ ] 3 find   - [ ] 4 cluster
- [ ] 5 refute   - [ ] 6 self-check   - [ ] 7 report   - [ ] 8 ledger   - [ ] 9 clean up
```

## 1. Triage
- `gh pr view <n> --json state,isDraft,title,body,baseRefName,baseRefOid,headRefOid,isCrossRepository,changedFiles`. Stop if it is closed or merged.
- Fetch the head and find the merge base (step 2), then list files with `git diff --numstat <merge_base> <headRefOid>`; its count must equal `changedFiles`.
- Classify each file: source; migration; infra and CI (CI workflows, IaC, container and deploy manifests, access policies); test or `qa/` (read for intent only); docs and config; manifest or lockfile; generated; vendored; snapshot; binary. Skip generated, vendored, snapshot and binary files and list them under coverage. If nothing reviewable remains, report CI and coverage and stop.
- Size = added plus removed lines in source, migration, and infra and CI files.
  - Under 50: one `reviewer` runs all seven lens sections in one pass.
  - 50 to 399: one `reviewer` per lens.
  - 400 to 1000: lenses 2 and 3 split by module, one agent per module; the other lenses run once over the whole PR. Report the size and its separate concerns as a should-fix finding.
  - Over 1000: report the size as a should-fix finding and ask Anand which part to review before going on.

## 2. Bundle
In `<scratchpad>/review-<owner>-<repo>-<n>/`. The `reviewer` agent is read-only, which keeps a prompt injection in the PR from writing anything; everything it needs goes in the bundle:
- `head/`: `git fetch origin pull/<n>/head` (works for forks) into the local clone, or into a blobless clone in the scratchpad (`git clone --filter=blob:none`). Confirm the fetched commit is `headRefOid`, then `git worktree add head/ <headRefOid>`.
- `merge_base = git merge-base <baseRefOid> <headRefOid>`. `diff.patch` is `git diff <merge_base> <headRefOid>`, never a two-dot diff against the base tip, which would show everything merged to base since as this PR's deletions.
- `deleted.md`: from the removed lines of the same range, one line per deleted file, symbol, route, column, config key or event: `path:line (base) | what was removed`. Nothing else goes in it.
- `conventions/`: the repo's and team's convention and guidance files (CLAUDE.md, AGENTS.md, REVIEW.md, CONTRIBUTING.md, scoped ones on each changed file's path), from `baseRefOid`, so a PR cannot rewrite the rules it is judged by.
- `standard/`: Anand's `~/.claude/rules/building.md`.
- `skill/`: copies of [lenses.md](lenses.md) and [refute.md](refute.md).
- `suppressions.md`: a copy of `~/personal/reviews/suppressions.md`, empty if none.
- `comments.md`: existing review comments and threads, with resolved state and the author's replies.
- `checks.md`: CI status, and each formatter, linter and type checker with whether it ran on this head in CI and its result. State plainly whether CI is green, red, or absent. Do not run them locally: that installs the PR's dependencies.
- `bundle.md`, built from metadata without reading the whole diff yourself:
  - the PR goal in one sentence (mark it INFERRED and make it the first question if the description does not state one); whether it is a draft; when `baseRefName` is not the default branch, that it is stacked on that PR;
  - `git diff --numstat` with each file's class, languages and frameworks;
  - the runtime and package versions the repo pins, or "not pinned" (then version-dependent claims are questions);
  - for each added or upgraded dependency, from the registry: it exists under that exact name, the version the lockfile resolves and its source URL, licence, first publish date, last release date, install scripts;
  - the paths above.

## 3. Find
Dispatch the lens agents from step 1, at most 15 at a time, each with the bundle path, its lens number (or "all seven" for a small PR) and, for a split agent, its module's paths. Each reads `skill/lenses.md` and returns its findings.

## 4. Cluster
Cluster the returned findings straight into `findings/merged.md` with stable ids; do not save the lens reports separately.
- Same root cause, one finding: list every location and the lenses that raised it. Different causes stay apart, even on one line; a finding that bundles two causes is split and each part takes its own severity.
- A merged finding takes the highest severity raised for its cause.
- `Seen, not mine` lines: drop each one whose location and cause a finding already covers. Write up the rest from the line, mark them "from seen", and send them to refute like any other.

## 5. Refute
- Skip refute only when the finding's rule is a quoted line from `conventions/` or `standard/` and its evidence is a single line in `head/`, or a single removed line in `diff.patch`, that breaks that quote on its face. A finding that needs a trace, a judgement of cost or a count goes to refute.
- Batch the rest by the code path they sit on (one feature flow, one module), up to eight per batch. One fresh `reviewer` per batch, in parallel, follows `skill/refute.md`.
- Save verdicts to `findings/verdicts.md`. A verdict or severity word outside refute.md's lists is invalid: send that finding back once. Keep stands, and unproven as questions. The refuter's severity is final. Pre-existing bugs go to their own section; everything else dropped goes to the Dropped list.

## 6. Self-check
- Re-open each kept finding's `path:line` in `head/` and confirm the line says what the finding claims, with a trigger, a rule and a fix; for quoted-rule findings, confirm the quote exists in the base convention file or the standard.
- A claim about framework or library behaviour that reading cannot settle may be checked with a throwaway probe in the scratchpad, on the versions `bundle.md` lists (for example `uv run --only-binary :all: --python <v> --with <pkg>==<v>`, `npm_config_ignore_scripts=true npx -p node@<v> -p <pkg>@<v>`), never installed into the repo. A probe never imports code from `head/` and never runs a package the PR adds or upgrades: the PR is untrusted and you hold the secrets. Such claims stay questions.
- For each open thread in `comments.md`, open its line in `head/` and record fixed or not fixed.
- Fix or drop any finding that fails; a dropped one goes to the Dropped list with the reason `self-check`.

## 7. Report
Start with CI status and the PR goal, and say first if it is a draft. Then blocking, should fix, questions, with severity as defined in `lenses.md`, Shared contract, each section ordered by harm, worst first. No praise.

Each item is at most three lines: `path:line`, what goes wrong and when, the rule broken, the fix. A question names the one fact that would decide it. Then:
- Existing comments still open: raised before, acknowledged or not, and not fixed in head.
- Pre-existing, not caused by this PR.
- Dropped: `id | verdict | reason`, one line each, so a wrong drop can be rescued.
- Coverage: lenses run, files skipped or split, areas not judged, claims probed.

## 8. Ledger
In `~/personal/reviews/<owner>-<repo>-<n>.md`, with the merge base and head commits reviewed: `| # | comment (who, path:line) | status | reply |`. Status: proposed (not posted yet), open, agreed, disputed, resolved, dropped. Add every existing comment and every kept finding. The reply column stays empty until Anand decides.

When Anand drops a finding as wrong, add one line to `~/personal/reviews/suppressions.md`: what was flagged and why it was wrong.

## 9. Clean up
Remove the `head/` worktree.

## Re-review after new pushes
Build the bundle as in step 2, with these differences:
- `diff.patch` is `git range-diff --remerge-diff <old_merge_base>..<old_head> <new_merge_base>..<new_head>`. It covers a rebase and a merge from base alike, and leaves out base changes merged in. `full.patch` is the current full PR diff, for context only.
- Lenses report only on what `diff.patch` shows changed, and the callers of what changed are in scope.
- `ledger.md` holds the open ledger items, and refuters also return `resolved`, `still open` or `disputed` for each.
- Say in the report what was not re-reviewed.

## Replies
- Discuss each comment with him. He decides.
- Draft the reply in his voice with the `voice-draft` skill.
- Never post a review, comment or reply yourself. He posts it.
