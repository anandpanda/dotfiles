---
name: coverage-diff
description: User-invocable as /coverage-diff. Mirrors the CI tests.sh diff-cover gate locally. Use when about to push, finishing a PR, or when CI flagged coverage. Pass an optional base branch (default origin/main).
disable-model-invocation: true
---

# /coverage-diff — local mirror of CI's diff-cover

Pantheon CI runs `services/pantheon/tests.sh` which:

1. Runs `pytest -n auto --dist worksteal --cov --cov-report=xml`
2. Computes lines changed vs the base branch (`GITHUB_BASE_REF`, defaults to `main` locally)
3. If lines changed > 30 → fails when `diff-cover coverage.xml --fail-under=75`. ≤ 30 lines → no gate.

This skill runs the same logic locally so you don't surprise CI.

## How to run

```bash
cd /home/coder/zamp/services/pantheon
bash tests.sh
```

That's it — `tests.sh` already has the full logic. The skill exists because:

- People forget the script is there and run `pytest` raw.
- It enforces base-branch alignment (`origin/main` locally vs `GITHUB_BASE_REF` in CI).

## Pre-flight checks

Before invoking the script:

1. Confirm you're on a feature branch: `git rev-parse --abbrev-ref HEAD` ≠ `main`.
2. Confirm `origin/main` is fetched: `git rev-parse origin/main` should succeed.
3. If not: `git fetch --no-tags --depth=50 origin main:refs/remotes/origin/main`.

## Reading the output

- Look for `FAIL` lines from diff-cover with file paths — those are uncovered lines added by your change.
- The 30-line threshold is in `tests.sh:14` — confirm against the live file before quoting it back.

## What to do when it fails

Follow `superpowers:test-driven-development` discipline: write the missing tests, don't lower the threshold, don't add `# pragma: no cover` to skip the gate.

If a missed line is genuinely untestable (e.g. a defensive `raise` that can't be reached), add an inline justification comment and tag `# pragma: no cover` — but do this rarely.
