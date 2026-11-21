# Retro ledger

Every proposal /retro has shown, and what Anand decided. This repo is public: each row is a generalised learning in project-neutral words, never a quote, name, path or piece of work content.

Actions: New, Update, Supersede, Split, Delete, Noop. Status: picked, rejected.

| date | session | learning | target | action | status |
|---|---|---|---|---|---|
| 2026-11-20 | 2b0d7f6f, 351ba55c, 4441f895, e26790b5 | A message sent while the agent works is answered in its next text, before further tool calls | rules/working-agreement.md | Update | picked |
| 2026-11-20 | 4441f895, 351ba55c, 971b6d82 | Answer at the scope named, first sentence; a wider scope is a one-line offer, not the work | rules/working-agreement.md | New | picked |
| 2026-11-20 | 4441f895, 1841caa4, 351ba55c | Open with a plain one-or-two-sentence answer, every term explained, then the depth; stated once | rules/working-agreement.md, rules/anand.md | Update | picked |
| 2026-11-20 | 351ba55c, 971b6d82 | A Claude Doc only when asked for; a doubt in the conversation gets a chat answer; explain skill triggers on a request for a doc | rules/working-agreement.md, rules/anand.md, skills/explain/SKILL.md | Update | picked |
| 2026-11-20 | 971b6d82, 34b0a95a, 4441f895, 351ba55c | A decision question stands alone in plain words with each outcome and a pick; one per message, last, so a yes answers it | rules/working-agreement.md | New | picked |
| 2026-11-20 | 4441f895, 2b0d7f6f, 351ba55c | Intent is a claim: read history and callers before calling behaviour a bug, explaining why it exists, or changing it | rules/evidence.md | New | picked |
| 2026-11-20 | e26790b5, a3da7bae, 351ba55c | Claims about all/none/only/breaks-nothing rest on the full list of the set, shown; one member is a sample | rules/evidence.md | New | picked |
| 2026-11-20 | 55a6695c, 4441f895, 351ba55c | Observed means the thing itself: code where work happens, an edit read back, changing state re-read before reporting | rules/evidence.md | Update | picked |
| 2026-11-20 | e26790b5, 4441f895, 47c52426 | Numbers and time estimates are claims: measured, same baseline, own build time | rules/evidence.md | New | picked |
| 2026-11-20 | 64200d42, e26790b5 | Remote branches after a fetch are a settling route; a PR is read from its own diff, never a local base | rules/evidence.md, skills/pr-description/SKILL.md | Update | picked |
| 2026-11-20 | a3da7bae | Third-party behaviour comes from official docs first; "undocumented" names the pages searched | rules/evidence.md | New | picked |
| 2026-11-20 | 4441f895, 351ba55c | A shared component names nothing of one consumer; walk a second consumer through it | rules/building.md | Update | picked |
| 2026-11-20 | 4441f895, 55a6695c | Nothing beyond the ask covers claims, tests, fixtures, setup and failure handling too | rules/building.md | Update | picked |
| 2026-11-20 | 4441f895 | A slice ships its capability whole; deferrals listed with their later cost | rules/building.md | Update | picked |
| 2026-11-20 | 971b6d82, 351ba55c | The heavy-run limit counts processes, not agents | rules/building.md, auto-memory note | Update | picked |
| 2026-11-20 | 4441f895, 5d6b0f28 | Background runs report stalls and dead processes; re-checked after a restart | rules/working-agreement.md | Update | picked |
| 2026-11-20 | e26790b5, a3da7bae, 351ba55c | Discussing or asking means no edits, ledger rows or launches; parked stays parked except a live security hole; held commands never run | rules/working-agreement.md | Update | picked |
| 2026-11-20 | 2b0d7f6f | Verify runs the change end to end, called as its real caller does | rules/lifecycle.md | Update | picked |
| 2026-11-20 | 4441f895, a3da7bae, e26790b5 | No comments in config, manifests or migrations; new names grepped for clashes; blank line between steps; agent-read text is interface | rules/building.md | Update | picked |
| 2026-11-20 | 351ba55c | The public harness carries no company, product, repo or person names | dotfiles CLAUDE.md, skills/explain/reference.md | New | picked |
| 2026-11-20 | 2b0d7f6f, e26790b5 | Work in the user's checkout on a switched branch; merge, never rebase; ask before stash, rebase, checkout --, restore | rules/building.md, settings.owned.json | Update | picked |
| 2026-11-20 | 5d6b0f28, a3da7bae, e26790b5 | Slices are stacked PRs that merge as one unless told otherwise | rules/building.md, rules/lifecycle.md | Update | picked |
| 2026-11-20 | a3da7bae, e26790b5 | PR descriptions are short, one diagram, no merge-risk section, only the final diff | rules/writing.md, skills/pr-description/SKILL.md | Update | picked |
| 2026-11-20 | 971b6d82 | Work on one's own tooling runs Build and Verify only, the full suite once before its commit | rules/lifecycle.md | Update | picked |
| 2026-11-20 | 4441f895 | Bound memory, not data: page or stream instead of capping; size limits only on untrusted input at the boundary | rules/building.md, review/lenses.md, review/areas.md | Update | picked |
| 2026-11-20 | 351ba55c | A later decision marks the ledger row it replaces as superseded | rules/building.md | Update | picked |
| 2026-11-20 | 351ba55c, e26790b5 | Secrets are never written to a file; access checks fail closed | rules/machine.md, rules/building.md | Update | picked |
| 2026-11-20 | 351ba55c | A prompt hook tagging short acknowledgements as not a go | hooks | New | rejected |
| 2026-11-20 | 2ab3b1fb | Fixing something does not include starting, restarting or rebuilding services; offer them | rules/working-agreement.md | Update | picked |
| 2026-11-20 | 47c52426, e26790b5, 1841caa4 | Define notation, labels and numbers before use | rules/working-agreement.md | Update | picked |
| 2026-11-20 | a3da7bae | Name the target of every action: repo, branch, environment, time start | rules/writing.md | New | picked |
| 2026-11-20 | 351ba55c | A stack review covers every PR and all three kinds of PR feedback | skills/review-change/SKILL.md | New | picked |
| 2026-11-20 | 351ba55c | Page style lives in the user rules, not project memory | rules/anand.md | New | picked |
| 2026-11-20 | 351ba55c | Base branch is read from recent merged PRs | work rules | Update | picked |
| 2026-11-20 | e26790b5 | A hand-run prod write is rehearsed on dev or staging first | rules/building.md | New | picked |
| 2026-11-20 | 34b0a95a | Missing access means handing over the exact command, never asking for a credential | rules/evidence.md | Update | picked |
| 2026-11-20 | several | Remaining single-session proposals from the 2026-11-20 runs, skipped as a batch | various | Noop | rejected |
| 2026-11-21 | 82cfbdd9, 3ee89ae2, 0e72d5aa, 0fc2c7e6, 8c4aa82c, d289602f | Scope is exact both ways: no wider (whole codebase, global setting) and no narrower; an unasked extra step is an offer; a named problem gets its fix | rules/working-agreement.md | Update | picked |
| 2026-11-21 | 16c53a77, 541e4493, 26b26d8d | Nothing beyond the ask covers parts, inputs, outputs, reports and plan steps; dictated text, lists and places are returned exactly | rules/building.md, rules/anand.md | Update | picked |
| 2026-11-21 | 1b2dad0a, d4b120c3, 0fc2c7e6, 4d5dd477, 81429322 | Design is a discussion: several principled, simple options incl. the codebase's way and the plain way; his sketch is the start, not the spec; recommend, discuss, he picks before any build | rules/building.md, rules/lifecycle.md | Update | picked |
| 2026-11-21 | 26b26d8d, a53816e6, d50f25ea, 0e72d5aa, 8c4aa82c, 4ed0081f | Settle a claim before stating it; reasons for options, snippet names, handed commands, runtime review findings and "I can't" are claims | rules/evidence.md | Update | picked |
| 2026-11-21 | fc951aee, 81429322, 4d5dd477 | A subagent's finding or an earlier summary is a report; read what it names before it reaches an answer or draft | rules/evidence.md | Update | picked |
| 2026-11-21 | 183cc52b, d50f25ea, 47363342 | A term is defined in every reply that uses it, not once per session | rules/working-agreement.md | Update | picked |
| 2026-11-21 | 913cafb0, 4ed0081f, 26b26d8d | Explain on one real case with its actual values, and real code lines with any diagram beside them | rules/working-agreement.md | Update | picked |
| 2026-11-21 | 16c53a77, a53816e6, 183cc52b, 81429322, 6a1708ae | A short follow-up refines what is on the table; a message with two nameable readings gets a one-line "which one" | rules/anand.md | Update | picked |
| 2026-11-21 | 16c53a77, 3ee89ae2, d4b120c3 | The answer or draft itself goes in chat, never only behind a link; files are named by absolute path | rules/working-agreement.md | Update | picked |
| 2026-11-21 | 86255c8b, 7e3de85b | An open PR under others' review is shared: push, rerun or cancel only what was named; check the review decision first | work rules | New | picked |
| 2026-11-21 | 82cfbdd9, a53816e6, fc951aee, 4ed0081f, d50f25ea, 81429322, 6873e989 | Review comments: one problem and one ask on separate lines, a why only when needed, "should we" asks, his words kept, a diagram for a race | skills/voice-draft/SKILL.md | Update | picked |
| 2026-11-21 | 3ee89ae2 | A colleague review never asks the author to split the PR; size is a coverage note only | review/run.md | Update | picked |
| 2026-11-21 | 82cfbdd9, a53816e6, 6873e989, 6a1708ae, 81429322 | Claude posts reviews, comments and replies once he confirms the exact draft; any later change is shown again | rules/building.md, rules/lifecycle.md, skills/voice-draft/SKILL.md, skills/review-change/SKILL.md | Supersede | picked |
| 2026-11-21 | d50f25ea | A hook blocks a second pytest while one runs, matched on the running program, not on shell text | work hooks | New | picked |
| 2026-11-21 | 82cfbdd9 | Own-tooling work gets an Ask stage before Build | rules/lifecycle.md | Update | rejected |
| 2026-11-21 | 82cfbdd9 | Ask rule for API calls that post through an input file | settings.owned.json | New | rejected |
| 2026-11-21 | 82cfbdd9 | A rule he states is written into the harness at once, even mid-discussion | rules/building.md | Update | rejected |
| 2026-11-21 | b9bff4a7 | Ask rule before creating a git worktree | settings.owned.json | New | rejected |
| 2026-11-21 | 26b26d8d | Code shape inside an agreed change is the agent's call | rules/working-agreement.md | Update | rejected |
| 2026-11-21 | 913cafb0 | A "how to" question gets steps only, nothing run | rules/working-agreement.md | Update | rejected |
| 2026-11-21 | 6a1708ae, 6873e989 | On a colleague's PR the repo's written rules beat the personal standard | work rules | Update | rejected |
| 2026-11-21 | d289602f | Load an app's env file inside the one command that needs it | rules/machine.md | New | rejected |
| 2026-11-21 | 1b2dad0a, 81429322 | Build exactly the model or sketch he gives | rules/building.md | Update | rejected |
| 2026-11-21 | d4b120c3 | One design only, alternatives shown as rejected, no menu | rules/building.md | Update | rejected |
| 2026-11-21 | 1b2dad0a, 7e3de85b | Walk every actor, deployment and data writer; at a server, possible means what the API accepts | rules/building.md | Update | rejected |
| 2026-11-21 | 7e3de85b, 81429322 | A reader-side fix that hides a stale copy is a workaround; a caveat does not demote the principled fix | rules/building.md | Update | rejected |
| 2026-11-21 | 6873e989 | An author's proposed fix is a design still under review | rules/building.md | Update | rejected |
| 2026-11-21 | 16c53a77, 4d5dd477, 47363342 | Before picking a mechanism, list the tool's options, read the reference's trigger, check each option's dependencies | rules/building.md, rules/evidence.md | Update | rejected |
| 2026-11-21 | d289602f | Each stated requirement is a ledger row at once; each named problem is its own criterion | rules/building.md, rules/lifecycle.md | Update | rejected |
| 2026-11-21 | 16c53a77, 4d5dd477 | Text an agent reads states the constraint itself, no soft defaults | rules/building.md | Update | rejected |
| 2026-11-21 | 971ad0ac | A usage search's hits are read, not counted | rules/evidence.md | Update | rejected |
| 2026-11-21 | 47363342 | A probe leaves nothing behind in the real setup | rules/evidence.md | New | rejected |
| 2026-11-21 | 47363342, 1b2dad0a | A mid-work question goes at the top of the next reply; a side answer ends with the work still owed | rules/working-agreement.md | Update | rejected |
| 2026-11-21 | 8203098a, 81429322 | Names in the fewest plain words; grep callers before naming | rules/building.md | Update | rejected |
| 2026-11-21 | b9bff4a7 | A comparison names its baseline; a "not" says what is true | rules/writing.md | Update | rejected |
| 2026-11-21 | 16c53a77 | An instruction to do something is the go for it | rules/working-agreement.md | Update | rejected |
| 2026-11-21 | 82cfbdd9, d50f25ea, 81429322, 3ee89ae2 | Review-skill extras: every finding shown, questions only after self-check, reply only on own threads, smallest fix in the diff, rebuild around an agreed design | skills/review-change/SKILL.md | Update | rejected |
| 2026-11-21 | 82cfbdd9 | Review facts: a later stacked PR's caller counts; key on the platform's own ids | rules/building.md | Update | rejected |
| 2026-11-21 | 26b26d8d | A live check is not a heavy run; independent steps start at once | rules/building.md | Update | rejected |
| 2026-11-21 | 26b26d8d | Progress at the interval he asks for | rules/working-agreement.md | Update | rejected |
| 2026-11-21 | 7e3de85b | Watch CI to green before calling a PR ready | rules/lifecycle.md | Update | rejected |
| 2026-11-21 | 7e3de85b | Read branch protection and release flow before a push plan | work rules | Update | rejected |
| 2026-11-21 | 0e72d5aa, 47363342 | Tools built for a remote workspace never depend on the laptop | rules/anand.md | Update | rejected |
| 2026-11-21 | 82cfbdd9 | Fill docs with the batch call to dodge per-call permission prompts | skills/explain/SKILL.md | Update | rejected |
