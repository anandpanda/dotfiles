---
name: phase-close
description: Use when Anand says close the phase, wrap up the phase or task, "are we done", or before calling a multi-step piece of work finished. Runs every closing check and reports what is left for him.
disable-model-invocation: true
---

# Phase close

A phase is done only when every check below has run and passed, or is reported as not run with the reason.

## Checks, in order
1. **Tests.** Run the suite for what changed. Report pass and fail counts next to the previous count (from STATUS or the last close). A drop in the count needs a reason.
2. **Lint.** Run the repo's linter. Zero findings, or each one listed.
3. **Doctor.** Run the repo's health or drift check if it has one.
4. **Git.** Clean working tree; every commit on the agreed branch; no stray files.
5. **Fresh review.** Dispatch the `reviewer` agent with the task, its acceptance criteria and the diff range. Give it the claims to check, not your reasoning.
6. **Fix all.** Fix every finding the reviewer raises that you can confirm, then re-run checks 1 to 4. Disagree with a finding only with evidence.
7. **doc-drift.** Compare the README, specs, plans and rule files against what was built. Fix each place where a document now says something untrue.
8. **What I got wrong.** List your own mistakes in this phase: wrong claims, rework, rules broken. Each with the cost and the lesson.
9. **STATUS.** Update the repo's STATUS file: what is done, the test count, what is next.
10. **Yours to do.** The list of things only Anand can do: decisions, manual steps, approvals, anything shared or irreversible.

## Anti-cheat contract
Follow the anti-cheat contract in `rules/building.md` throughout. A check that could not run did not pass. Never mark the phase done with a failing or skipped check.

## Report
One table: check, result, evidence (command and its output count). Then What I got wrong, then Yours to do.
