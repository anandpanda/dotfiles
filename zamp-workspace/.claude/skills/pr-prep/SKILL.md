---
name: pr-prep
description: User-invocable as /pr-prep. Run before opening or updating a PR. Executes the local quality gates (ruff, pytest, diff-cover, gitleaks) and drafts a PR description in Anand's why/how/verified/summary template. Reuses superpowers:verification-before-completion for the gate step.
disable-model-invocation: true
---

# /pr-prep — pre-PR checklist + description draft

## Step 1: gates (must all pass before drafting)

Run these from the repo root for the changed files. Stop and fix on any failure — don't paper over.

### Pantheon

```bash
cd /home/coder/zamp/services/pantheon

# Lint + format
ruff check --fix pantheon_v2/
ruff format pantheon_v2/

# Tests + coverage gate
bash tests.sh

# Secret scan
gitleaks protect --staged --redact --no-banner || true   # warn-only locally; CI is the hard gate
```

### Frontend (when applicable)

```bash
cd /home/coder/zamp/services/application-platform-frontend
ESLINT_USE_FLAT_CONFIG=false npx eslint <changed-files>
npx tsc --noEmit
# tests command varies — check package.json scripts
```

## Step 2: verify before claiming done

Invoke `superpowers:verification-before-completion`. Read the actual output of every command above; don't assume exit code 0 means success.

## Step 3: draft the PR description

Use this exact template — Anand's preferred shape:

```markdown
## Why

<problem statement, motivation, ticket link if any. Two or three sentences.>

## How

<approach + key decisions. Bullet the touched components or layers.>
- <component A>: <what changed>
- <component B>: <what changed>
- <decision>: <why this approach over alternative X>

## How verified

<exact commands you ran + their actual output highlights. Screenshots / smoke-call traces for UI/API changes.>

```bash
# What was run
$ bash tests.sh
# Actual output (excerpt)
...
```

## Summary of what happened

<chronological narrative of the work, including dead-ends and course corrections. This is the "story" — what you tried, what didn't work, what stuck.>
```

### Rules for the description

- **No Claude attribution.** No `Co-Authored-By: Claude`, no 🤖, no "Generated with Claude Code". The `includeCoAuthoredBy: false` setting handles commits; PR bodies are manual.
- **No hedge words** in any section — this is a `factual-mode` artifact. Cite paths, paste real command output, no "should work".
- **Linked tickets**: drop the URL at the top of "Why".
- **For multi-region releases** (pantheon prod-eu, prod-me, prod-us): add a "Rollout plan" section listing the regions and order.

## Step 4: open / update the PR

Push only with explicit permission in the current turn. Then:

```bash
gh pr edit "$PR_LINK" --title "<concise title>"
gh pr edit "$PR_LINK" --body "$(cat /tmp/pr-body.md)"
gh pr ready "$PR_LINK"   # if still draft
gh pr view "$PR_LINK"    # confirm
```

## What this skill does NOT do

- Doesn't push (push requires explicit user authorization per global rule).
- Doesn't open the PR — it drafts the body. Opening is a user action.
- Doesn't replace `pr-review-toolkit:review-pr` — run that **before** /pr-prep for a deeper code review.
