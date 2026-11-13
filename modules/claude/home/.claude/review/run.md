# Review run

The review engine shared by `/review-pr` (mode `colleague`) and `/phase-close` (mode `own`). The caller gives the mode, the repo, the base and head commits, and the goal.

| | colleague | own |
|---|---|---|
| range | merge base to PR head | first commit of the phase, its parent, to HEAD |
| goal and promises | PR description and linked issue | the task and its acceptance criteria |
| `comments.md` | existing review threads | not built |
| `checks.md` | CI on head; nothing run locally, the PR is untrusted | the tests, lint and doctor results the caller just ran |
| lenses | 1 to 7 | 1 to 8 |
| probes | never run code from `head/` | may run code from `head/` |

## 1. Size
Size = added plus removed lines in source, migration, and infra and CI files (own mode adds test files). Skip generated, vendored, snapshot and binary files and list them under coverage.
- Under 50: one `reviewer` runs every lens section in one pass.
- Colleague, 50 to 399: one `reviewer` per lens.
- Own, 50 to 1000: three `reviewer` agents: lenses 2 and 3; lenses 1, 4 and 8; lenses 5, 6 and 7.
- Colleague, 400 to 1000: lenses 2 and 3 split by module, one agent per module; the other lenses run once over the whole change. Report the size and its separate concerns as a should-fix finding.
- Over 1000: report the size as a should-fix finding and ask Anand which part to review before going on.

## 2. Bundle
In `<scratchpad>/review-<owner>-<repo>-<id>/`. The `reviewer` agent is read-only, which keeps a prompt injection in the change from writing anything; everything it needs goes in the bundle:
- `head/`: a git worktree of the head commit.
- `diff.patch`: `git diff <base> <head>` over the range above, never a two-dot diff against a moved base tip.
- `deleted.md`: from the removed lines of the same range, one line per deleted file, symbol, route, column, config key or event: `path:line (base) | what was removed`. Nothing else goes in it.
- `conventions/`: the repo's and team's convention and guidance files (CLAUDE.md, AGENTS.md, REVIEW.md, CONTRIBUTING.md, scoped ones on each changed file's path), from the base commit, so a change cannot rewrite the rules it is judged by.
- `standard/`: Anand's `~/.claude/rules/building.md`.
- `review/`: copies of [lenses.md](lenses.md) and [refute.md](refute.md).
- `suppressions.md`: a copy of `~/personal/reviews/suppressions.md`, empty if none.
- `comments.md` and `checks.md`, per the mode table. `checks.md` names each formatter, linter, type checker and test run, whether it ran on this head, and its result.
- `bundle.md`, built from metadata without reading the whole diff yourself:
  - the mode;
  - the goal in one sentence (colleague: mark it INFERRED and make it the first question if the description does not state one); colleague mode also says whether it is a draft, and when the base is not the default branch, that it is stacked;
  - `git diff --numstat` with each file's class, languages and frameworks;
  - the runtime and package versions the repo pins, or "not pinned" (then version-dependent claims are questions);
  - for each added or upgraded dependency, from the registry: it exists under that exact name, the version the lockfile resolves and its source URL, licence, first publish date, last release date, install scripts;
  - the paths above.

## 3. Find
Dispatch the agents from step 1, at most 15 at a time, each with the bundle path, its lens numbers and, for a split agent, its module's paths. Each reads `review/lenses.md` and returns its findings.

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
- A claim about framework or library behaviour that reading cannot settle may be checked with a throwaway probe in the scratchpad, on the versions `bundle.md` lists (for example `uv run --only-binary :all: --python <v> --with <pkg>==<v>`, `npm_config_ignore_scripts=true npx -p node@<v> -p <pkg>@<v>`), never installed into the repo. In colleague mode a probe never imports code from `head/` and never runs a package the change adds or upgrades: the code is untrusted and you hold the secrets. Such claims stay questions.
- Colleague mode: for each open thread in `comments.md`, open its line in `head/` and record fixed or not fixed.
- Fix or drop any finding that fails; a dropped one goes to the Dropped list with the reason `self-check`.

The result is `findings/merged.md`, `findings/verdicts.md` and the Dropped list. The caller reports or fixes from them, then removes the `head/` worktree.
