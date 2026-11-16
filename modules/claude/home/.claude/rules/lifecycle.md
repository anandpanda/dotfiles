# Change lifecycle

The goal: a PR that no reviewer, human or bot, has anything left to comment on. Anand and Claude agree the design; Claude carries the change to the PR, keeps him in sync and brings him only the decisions that are his. Quality comes from building it right: Build applies the same checklist Check later holds it to, so Check finds little and ends fast.

## Stages
Set the appetite at Ask: how much the change deserves. A one-file fix runs the stages lightly; a feature runs them in full.

1. **Ask.** Write the problem in one paragraph, every promise as an acceptance criterion, and the appetite. Restate it to him; settle every vague word.
2. **Understand.** Write how it works today, who calls it, its constraints, how prod does it. Every claim labelled per `evidence.md`; unverified ones settled before design.
3. **Design.** Options, the chosen design and its tradeoffs; rows in the decisions ledger. Checked against the standard, stress-tested, read by an independent designer. **His go.**
4. **Slice.** Cut the design into parts that each work, are tested and can merge without the later ones, in an order with no cycles; each part is a PR, a few hundred lines where possible.
5. **Plan** (per slice). Tasks; **claims**, short statements of what must be true when done, each checkable by a test; **threats**, how each boundary and store could be abused or fail quietly, including that every failure is recorded and reported; deploy notes naming every run, file and stored shape the slice touches. Every promise maps to a task and a claim; every boundary has a threat line.
6. **Build** (per slice). Tests first, then code, in commits split by kind. Walk the lenses, the break areas and the repo's written rules (`CLAUDE.md` or `AGENTS.md` and the convention and codebase guides they point to) while writing each piece. Keep the repo's own acceptance checks in sync in the same change as the tests, whatever the repo uses to state and check behaviour (acceptance tests, specs, QA claims): add, change or delete them alongside. Linters and types clean.
7. **Check** (per slice). `/review-change`: readers and breakers per part and per seam, on the review stack when the repo has one; the loop below.
8. **Verify** (per slice). The affected checks, then the full test suite once. A check that could not run is reported as not run.
9. **Ship** (per slice). PR and description per `pr-description`; replies to reviewers drafted for him per `voice-draft`, never posted by Claude.
10. **Learn.** For each comment that still lands: why it escaped and the checklist line it suggests (a lens, an area, a line of the standard). **His go on each line**; the source is the comment.

## The Check loop
Repeat until a round finds nothing worth fixing, minor items included.
1. Split into parts and seams; a reader and a breaker each. Full coverage: every hunk against every lens, every surface on some breaker's map. Neutral prompts: a part or an area and a mindset, never the expected answers.
2. Refute every finding with a fresh agent; only survivors count.
3. Cluster survivors by root cause, not by file.
4. Fix each cluster at the design level, once, at its owner. A guard, flag, special case or second home for one decision is a workaround: fix it properly, or bring it to him named as a workaround. A fix that changes the agreed design goes to him first.
5. Every fix starts as a failing test that reproduces the finding.
6. Loop sync, then another round only on the parts and seams still producing real findings. The loop ends when a round is quiet and every map is complete.

## Where he is involved
| Touchpoint | When | He gets |
|---|---|---|
| Design | Before code | Problem, options, recommendation, tradeoffs, slices; he decides |
| Decisions during build | When one comes up | The decision, its evidence, options, a recommendation; only that point waits |
| Loop sync | After every Check round | Found, fixed and how, what needs him, whether another round runs |
| Final sync | At Verify, before the PR | Evidence, anything still open, what the PR will say |
| Learn | After a comment lands | The comment, why it escaped, the line to add |

A decision is his when it changes the agreed design or scope, touches anything shared, in prod or irreversible, or trades away something agreed. Small reversible steps inside the agreed design are taken and logged.

Never brought to him: an unverified claim, a question the code, a probe or the docs can answer, "should I check X". Close those and show the answer in the sync.
