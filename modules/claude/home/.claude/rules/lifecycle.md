# Change lifecycle

The goal: a PR that no reviewer, human or bot, has anything left to comment on. Anand and Claude agree the design; Claude carries the change to the PR, keeps him in sync and brings him only the decisions that are his. Quality comes from building it right: Build applies the same checklist Check later holds it to, so Check finds little and ends fast.

## Stages
Set the appetite at Ask: how much the change deserves. A one-file fix runs the stages lightly; a feature runs them in full. Work on his own tooling (dotfiles, skills, scripts) runs Build and Verify only: tests first, the affected tests, then the full suite once before its commit; no Check loop unless he asks.

1. **Ask.** Write the problem in one paragraph, every promise as an acceptance criterion, and the appetite. Restate it to him; settle every vague word.
2. **Understand.** Write how it works today, who calls it, its constraints, how prod does it. Every claim labelled per `evidence.md`; unverified ones settled before design.
3. **Design.** Principled options, a recommendation and why each other loses (`building.md`, Principle 1), discussed until he picks; the chosen design and its tradeoffs; rows in the decisions ledger. Checked against the standard, stress-tested, read by an independent designer. **His go.**
4. **Slice.** Cut the design into parts that each work and are tested, in an order with no cycles; each part is a stacked PR, a few hundred lines where possible, and the stack merges as one unless he says otherwise. A slice ships its capability whole: do not narrow a kind the agreed design needs, and list each deferral with what adding it later costs.
5. **Plan** (per slice). Tasks; **claims**, short statements of what must be true when done, each checkable by a test; **threats**, how each boundary and store could be abused or fail quietly, including that every failure is recorded and reported; deploy notes naming every run, file and stored shape the slice touches. Every promise maps to a task and a claim; every boundary has a threat line.
6. **Build** (per slice). Tests first, then code, in commits split by kind. Walk the lenses, the break areas and the repo's written rules (`CLAUDE.md` or `AGENTS.md` and the convention and codebase guides they point to) while writing each piece. Keep the repo's own acceptance checks in sync in the same change as the tests, whatever the repo uses to state and check behaviour (acceptance tests, specs, QA claims): add, change or delete them alongside. Linters and types clean.
7. **Check** (per slice). `/review-change` in own mode: readers and breakers per part and per seam, on the review stack when the repo has one, looping until a round finds nothing worth fixing, minor items included.
8. **Verify** (per slice). Run the change end to end yourself on the local stack, calling it as its real caller does (the same identity and entry point); never leave him a test you can run. Then the affected checks, then the full test suite once. A check that could not run is reported as not run.
9. **Ship** (per slice). PR and description per `pr-description`; replies to reviewers per `voice-draft`.
10. **Learn.** For each comment that still lands: why it escaped and the checklist line it suggests (a lens, an area, a line of the standard). **His go on each line**; the source is the comment.

## Where he is involved
| Touchpoint | When | He gets |
|---|---|---|
| Design | Before code | Problem, options, recommendation, tradeoffs, slices; he decides |
| Decisions during build | When one comes up | The decision, its evidence, options, a recommendation; only that point waits |
| Loop sync | After every Check round | Found, fixed and how, what needs him, whether another round runs |
| Final sync | At Verify, before the PR | Evidence, anything still open, what the PR will say |
| Learn | After a comment lands | The comment, why it escaped, the line to add |
