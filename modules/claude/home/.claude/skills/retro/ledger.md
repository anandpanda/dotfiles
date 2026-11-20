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
