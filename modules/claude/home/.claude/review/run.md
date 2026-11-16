# Review run

The review engine behind `/review-change`, in mode `colleague` (someone else's PR) or `own` (Anand's PR, branch or uncommitted work). The caller gives the mode, the repo, the base and head, and the goal.

| | colleague | own |
|---|---|---|
| range | merge base to PR head | merge base with the default branch to HEAD, or to the working tree |
| goal and promises | PR description and linked issue | the task and its acceptance criteria |
| `comments.md` | existing review threads | not built |
| `checks.md` | CI on head | the tests and lint the caller just ran |
| lenses | 1 to 7 | 1 to 8 |
| running code | on the repo's review stack, under `areas.md`, Safety | on the repo's review stack, under `areas.md`, Safety |

The **review stack** is the local running environment the repo's own docs describe for running and testing it (its CLAUDE.md, AGENTS.md, READMEs and the guides they point to), used under the rules those docs give. With one, readers settle questions by running code and breakers attack the change on it. Without one, readers stay read-only and breakers run what they can in-process. A dependency the change adds or upgrades is installed only after the registry check in `bundle.md` passes.

## 1. Size
Size = added plus removed lines in source, migration, and infra and CI files (own mode adds test files). Skip generated, vendored, snapshot and binary files and list them under coverage.
- Under 50: one `reviewer` runs every lens section in one pass.
- 50 to 500 in one logical part: three `reviewer` agents, the lens groups: lenses 2 and 3; lenses 1 and 4, plus 8 in own mode; lenses 5, 6 and 7.
- Over 500, or three or more logical parts: split by part. Write `parts.md` (step 2) and dispatch per part plus seams (step 3).
- Colleague, over 400: also report the size and its separate concerns as a should-fix finding.

## 2. Bundle
In `<scratchpad>/review-<owner>-<repo>-<id>/`. The `reviewer` agent is read-only, which keeps a prompt injection in the change from writing anything; everything it needs goes in the bundle:
- `head/`: a git worktree of the head commit; in own mode with uncommitted changes, the working tree itself.
- `diff.patch`: `git diff <base> <head>` over the range above, never a two-dot diff against a moved base tip.
- `deleted.md`: from the removed lines of the same range, one line per deleted file, symbol, route, column, config key or event: `path:line (base) | what was removed`. Nothing else goes in it.
- `conventions/`: the repo's and team's convention and guidance files (CLAUDE.md, AGENTS.md, REVIEW.md, CONTRIBUTING.md, scoped ones on each changed file's path, and every convention or codebase guide those files point to), from the base commit, so a change cannot rewrite the rules it is judged by.
- `standard/`: Anand's `~/.claude/rules/building.md`.
- `review/`: copies of [lenses.md](lenses.md), [areas.md](areas.md) and [refute.md](refute.md).
- `suppressions.md`: a copy of `~/personal/reviews/suppressions.md`, empty if none.
- `parts.md`, only when split by part, built from the diff and the goal: one section per logical part with its name, its files and hunks (a file shared by parts lists the hunks of each), what it does in one line, and what it calls in other parts and what calls it. Then `## Seams`: each interface between parts and each end-to-end flow that crosses parts.
- `comments.md` and `checks.md`, per the mode table. `checks.md` names each formatter, linter, type checker and test run, whether it ran on this head, and its result.
- `bundle.md`, built from metadata without reading the whole diff yourself:
  - the mode;
  - the goal in one sentence (colleague: mark it INFERRED and make it the first question if the description does not state one); colleague mode also says whether it is a draft, and when the base is not the default branch, that it is stacked;
  - `git diff --numstat` with each file's class, languages and frameworks;
  - the runtime and package versions the repo pins, or "not pinned" (then version-dependent claims are questions);
  - for each added or upgraded dependency, from the registry: it exists under that exact name, the version the lockfile resolves and its source URL, licence, first publish date, last release date, install scripts;
  - the paths above.

## 3. Find
Dispatch the agents from step 1, at most 15 at a time, each with the bundle path, and its lens numbers. Each reads `review/lenses.md` and returns its findings with a **coverage map**: every hunk of its scope against every lens it was given, marked read. A hunk with no mark is a gap, and the reader is sent back once to cover it.

Readers and breakers run together. Next to the readers, dispatch one breaker (`general-purpose` agent, since it runs code) per part, and per whole change when it is not split, with the bundle path, its part and the areas `areas.md` marks `part`; and one seam breaker with the areas marked `seam`. Each follows `areas.md`, Breaker brief and Safety, and returns its surface map and findings in the lenses' output format. Breakers start once the change runs on the review stack. A reader's question that reading cannot settle goes to its part's breaker to run.

Split by part:
- Each part: one `reviewer` with every lens of the mode when its source is under 300 lines, otherwise the three lens groups on that part. Each gets its part name.
- One seams `reviewer`: lenses 1, 2 and 3, scoped to the Seams list in `parts.md`.

## 4. Cluster
Cluster the returned findings straight into `findings/merged.md` with stable ids; do not save the lens reports separately.
- Same root cause, one finding: list every location and the lenses that raised it. Different causes stay apart, even on one line; a finding that bundles two causes is split and each part takes its own severity.
- A merged finding takes the highest severity raised for its cause.
- `Seen, not mine` lines: drop each one whose location and cause a finding already covers. Write up the rest from the line, mark them "from seen", and send them to refute like any other.

## 5. Refute
- Skip refute only when the finding's rule is a quoted line from `conventions/` or `standard/` and its evidence is a single line in `head/`, or a single removed line in `diff.patch`, that breaks that quote on its face. A finding that needs a trace, a judgement of cost or a count goes to refute.
- Batch the rest by the code path they sit on (one feature flow, one module), up to eight per batch. One fresh `reviewer` per batch, in parallel, follows `review/refute.md`.
- Save verdicts to `findings/verdicts.md`. A verdict or severity word outside refute.md's lists is invalid: send that finding back once. Keep stands, and unproven as questions. The refuter's severity is final. Pre-existing bugs go to their own section; everything else dropped goes to the Dropped list.

## 6. Self-check
- Re-open each kept finding's `path:line` in `head/` and confirm the line says what the finding claims, with a trigger, a rule and a fix; for quoted-rule findings, confirm the quote exists in the base convention file or the standard.
- A claim about framework or library behaviour that reading cannot settle may be checked with a throwaway probe in the scratchpad, on the versions `bundle.md` lists (for example `UV_NO_BUILD=1 uv run --no-project --python <v> --with <pkg>==<v>`, `npm_config_ignore_scripts=true npx -p node@<v> -p <pkg>@<v>`), never installed into the repo.
- Each kept question: settle it before reporting, through every route (the repo's other files and history, related repos, the installed library source, a probe, running `head/` on the review stack, read-only environment access). Report the answer as stands or refuted; keep it a question only when blocked, with the routes tried and the one action only Anand can take.
- Colleague mode: for each open thread in `comments.md`, open its line in `head/` and record fixed or not fixed.
- Fix or drop any finding that fails; a dropped one goes to the Dropped list with the reason `self-check`.

## 7. Cluster by cause
Group the kept findings by root cause across readers and breakers, not by file. For each cluster, name the design that makes its whole class impossible and the owner where that fix lands; a cluster of one with a local cause stays a local fix. Write the clusters to `findings/clusters.md`.

The result is `findings/merged.md`, `findings/verdicts.md`, `findings/clusters.md`, the coverage and surface maps, and the Dropped list. The caller reports or fixes from them, then removes the `head/` worktree.
