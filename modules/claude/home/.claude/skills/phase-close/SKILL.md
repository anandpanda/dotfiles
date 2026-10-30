---
name: phase-close
description: /phase-close closes a phase or task. Runs every closing check, fixes what the fresh review finds, updates the docs and STATUS, and reports what is left for Anand.
disable-model-invocation: true
---

# Phase close

A phase is done only when every check below has run and passed, or is reported as not run with the reason.

## Checks, in order
1. **Tests.** Run the full suite, so the count compares with the previous count (from STATUS or the last close). Report pass and fail. A drop in the count needs a reason.
2. **Lint.** Run the repo's linter. Zero findings, or each one listed.
3. **Doctor.** Run the repo's health or drift check if it has one.
4. **Fresh review.** Write the phase's diff to a diff file in the session scratchpad (`git diff <first>^..HEAD > <scratchpad>/phase.diff`). Dispatch the `reviewer` agent with the task, its acceptance criteria and that path. Give it the claims to check, not your reasoning.
5. **Fix all.** Fix every finding you can confirm. Disagree with a finding only with evidence.
6. **doc-drift.** Compare the README, specs, plans and rule files against what was built. Fix each place where a document now says something untrue.
7. **STATUS.** Update the repo's STATUS file: what is done, the test count, what is next.
8. **Clean tree.** Commit the fixes, doc and STATUS edits, then re-run checks 1 to 3. Last, `git status` shows a clean tree on the agreed branch with no stray files.

## Anti-cheat contract
Follow the anti-cheat contract in `rules/building.md` throughout. A check that could not run did not pass. Never mark the phase done with a failing or skipped check.

## Report
One table: check, result, evidence (command and its output count). Then:
- **What I got wrong.** Your own mistakes in this phase: wrong claims, rework, rules broken. Each with the cost and the lesson.
- **Yours to do.** The things only Anand can do: decisions, manual steps, approvals, anything shared or irreversible.
