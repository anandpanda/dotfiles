---
name: pr-description
description: Use when writing or updating a pull request description, or when Anand asks for a PR body, PR summary or "write the PR". Writes what the PR is and how it solves it, with a diagram and merge risk.
---

# PR description

For the people who review it and for Anand later. Concise, in his voice (`rules/writing.md`).

## Sections
1. **What and why.** One short paragraph: the problem and what this PR does about it.
2. **How.** The approach and the key decisions, each with its why. Name the files or modules that carry the change.
3. **Before / after.** When behaviour, output or structure changes: two short blocks, or a two-column table.
4. **Diagram.** At least one mermaid diagram of the type that fits (flow, sequence, state, architecture). It must match the code in the diff: every box and arrow is something you read.
5. **Merge risk.** What could break, who or what is affected, rollout or migration steps, how to roll back. "Low" needs a reason.
6. **What did not change.** For refactors: the behaviour, interfaces and data that stay the same.

## Rules
- No testing section. Tests are in the diff and CI.
- No AI attribution: no Co-Authored-By line, no "Generated with" line, no mention of Claude.
- No UNVERIFIED claim. Every statement is checked against the diff or a run.
- No restating the diff file by file. No praise, no filler.
- Updating an existing description: keep what is still true, replace what is not.
