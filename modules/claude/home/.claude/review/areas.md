# Break areas

Each breaker runs the change and attacks it. Reviewers read the change against the lenses; breakers run it against these areas. Both lists are one checklist: every area names the lens that owns its harm, and a breaker's finding uses that lens's severity and output format (`lenses.md`, Shared contract).

## Areas

| Area | What the breaker attacks | Lens | Part or seam |
|---|---|---|---|
| Feature off | With the new feature unused or switched off, everything behaves exactly as on the base: same results, no extra calls, no new failure mode | 1 | seam |
| Work in flight | Old runs, queued messages, cached values and stored data meet the new code; long-running work the change touches, including work it spawned or handed off, at the moment of deploy | 1 | seam |
| Stored shapes and consumers | Files, records, events and APIs others read or write: old ones still load, new ones still read by existing consumers | 1 | seam |
| Inputs and sizes | Every entry point with empty, blank, huge, deeply nested, self-referencing, non-finite, duplicated and wrong-typed values; every store and payload with no size bound | 2, 3 | part |
| Sensitive data | Everywhere data comes to rest or leaves: stores, results, messages, logs, errors, job and event histories; secrets nested at any depth, under any name, inside strings | 4 | part |
| Tenancy and identity | Another tenant's ids, ids from input instead of the authenticated identity, existence leaks, acting as the wrong party | 4 | part |
| Context across boundaries | Identity and scope carried across every process or service hop: lost (work silently runs unscoped) or leaked (unrelated work picks it up) | 4 | seam |
| Concurrency and retries | The same work twice, at once, retried after it wrote, redelivered, reordered; locks that expire or never release | 3 | part |
| Lifecycle and partial failure | State started, used, ended, expired, cancelled or abandoned; a later step failing after an earlier one wrote; what is left behind | 3 | part |
| Failure visibility | Every failure path: is it recorded, and does someone who will act learn of it; does a failure that will repeat stop at once | 3 | part |
| Acting on someone's behalf | A part that answers, approves or acts for a user or another system: acts when it should not, on the wrong thing, as the wrong party, twice, or never | 4 | part |

A repo may add areas in its own docs; they follow the same columns.

## Breaker brief

Give each breaker its part or seam, its areas and the bundle path. Nothing else about what to look for: no expected bugs, no files to start from, no earlier findings. A hint narrows the search and makes an independent reviewer's overlap meaningless.

The breaker:
1. Maps its surface first: every entry point, stored shape, hop and failure path its part or seam has for its areas. The map is the first section of its report; an unmapped surface is a gap. An area with no surface in this part or seam says so in the map, with the reason, and gets no attack.
2. Attacks with its own hypotheses, on the running stack.
3. Reports only what it reproduced: the input or sequence, observed against expected, the cause at `path:line` on `head/`, the repro script and its output path. A static finding needs the exact line and the rule it breaks.
4. Ends with what it tried that held, and what it could not test and why.
5. Returns the whole report as its final message; subagents cannot write report files.

## Safety

- Run only on the review stack (`run.md`) and follow its own rules. Check the target before the first call of every script; a script that reaches anything else stops at once and is reported.
- Write only data the breaker creates. Never flush, drop, truncate, bulk-update or delete data it did not create.
- Secret-shaped values are canaries (`canary-<random>`). Never print, log or write a real secret.
- One heavy run at a time (a test suite, many jobs or processes at once) behind one shared lock.
- Never edit, stage, commit, stash or switch branches in a checkout. Scripts and outputs go in the breaker's own folder.
- Before installing a dependency the change adds or upgrades, check it against `bundle.md`'s registry facts. A look-alike name, a brand-new package or an unexpected install script is not installed; it is a finding.
- Clean up what it started: close what it opened, stop its own running work, remove its own data.
