---
name: grill
description: Use when Anand asks to be grilled, asks "what am I missing", wants a design, plan or idea stress-tested, or asks for the open questions before building. Runs numbered rounds of questions, each with a recommended answer.
---

# Grill

Find the decisions a plan has not made yet, and get them made.

## Before asking
- Facts are yours to look up: read the code, docs, config and history first. Never ask him what a file, a doc or a command can answer.
- Decisions are his: design, scope, tradeoffs, anything shared, prod, irreversible or billable.

## Rounds
- Number every question across the whole session (1, 2, 3, ... continuing into later rounds), so he can answer "3: yes".
- Up to five questions per round, most consequential first.
- Each question:
  - the question in one line;
  - why it matters: what breaks or changes depending on the answer;
  - the options when there are several;
  - **Recommended:** your answer and the one-line reason, from evidence you cite.
- After his answers: log each decision in `DECISIONS.md` (see `rules/building.md`), then ask the next round only about what his answers opened.
- Stop when no open decision would change what gets built. Say so, and list the decisions made.

## Never
- Questions with an obvious answer, or ones you could settle by reading.
- Building, editing or committing during the grill.
- Treating "ok" or a question back as an answer. Ask again for that number.
