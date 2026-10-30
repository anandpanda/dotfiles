---
name: research
description: Use when Anand asks to research, compare or choose a tool, library, approach or setting, asks "what's the best way to", or a decision needs facts from outside the repo. Docs first, every claim cited, one recommendation.
---

# Research

## Sources, in order
1. Official docs for the version he has installed (check the version first).
2. The project's source, changelog and issues.
3. Practitioners: engineering blogs, talks, well-maintained examples.
4. Discussion threads only as signals, never as the only source for a claim.

Use the `researcher` agent for broad or parallel searches; give it the question and a file for findings.

## Every claim
- Cited with a link to the exact page or line, and the date or version it applies to.
- Open every link before giving it. A link you could not open is listed as not checked.
- Separate what a source says from what you infer (`rules/evidence.md`).

## Output
1. The answer to the question asked, in one or two lines.
2. Options compared in one table: what it is, fit for his setup, cost (money, daily friction, maintenance), risk, source.
3. **One recommendation**, with the tradeoff and why it wins. Name the simpler option first when it is close (`rules/anand.md`).
4. What you could not verify, and the command or page that would settle it.

Nothing is installed or changed from research alone. He decides.
