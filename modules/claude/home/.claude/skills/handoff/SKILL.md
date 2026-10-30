---
name: handoff
description: /handoff writes STATUS and the decisions ledger before a session is cleared or ended, and gives a five-line summary for the next session.
disable-model-invocation: true
---

# Handoff

Leave the next session able to continue without this conversation.

## Update the files
1. **STATUS** in the repo (or the project's status file): goal, what is done, what is in progress, what is next, test count, branch and last commit.
2. **`DECISIONS.md`** in the auto-memory folder (`rules/building.md`): add every decision made this session that is not there yet, with his quote as the source or INFERRED.

## Label every claim
Each line in STATUS and in the summary is one of:
- **observed**: you ran or read it this session, with the source;
- **inferred**: follows from something observed, with what it follows from;
- **assumed**: neither, with the command that would check it.

## Summary to him
Five lines at most:
1. Where it stands.
2. What changed this session.
3. What is next.
4. Open decisions that are his.
5. Risks or anything assumed.
