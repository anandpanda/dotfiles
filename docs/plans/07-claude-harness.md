# Claude Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `claude` module that installs Anand's Claude Code harness on every machine: the working agreement, six hooks, memory re-injection, nine skills, three agents, owned settings, plugins and a statusline.

**Architecture:** `modules/claude/home/.claude/**` is linked file by file like every other module. Hooks are bash scripts reading the hook JSON on stdin with `jq`, sharing `hooks/lib.sh`. `settings.json` is never linked: `install.sh` merges only the keys in `settings.owned.json` into the live file, so `/model` and `/config` changes stay Anand's.

**Tech Stack:** bash 3.2, jq, bats, shellcheck, shfmt; Claude Code ≥ 2.1.285.

**Spec:** `docs/specs/07-claude-harness.md`

## Global Constraints

- Bash 3.2 compatible (macOS); `shellcheck -S info` and `shfmt -i 2 -ci` clean; tests hermetic (temp HOME, fake binaries on PATH, never the real `~/.claude`).
- No hook judges or blocks a command (Anand: parsing can never cover every form). Consequences are handled by native `permissions.deny` and `permissions.ask` rules, which apply in bypass mode. Hooks only add context (plain stdout or `{"hookSpecificOutput":{"hookEventName":…,"additionalContext":…}}`) or format a file, and fail open.
- Every hook path in settings is absolute via `$HOME/.claude/hooks/<name>`.
- Sessions run in bypass permission mode by Anand's choice: `"permissions": {"defaultMode": "bypassPermissions"}` is owned. Explicit ask rules still prompt and deny rules still block in bypass (permission-modes docs); allow rules have no effect there, so none are owned.
- Owned settings, verbatim: `"attribution": false`, `"cleanupPeriodDays": 365`, `"pluginConfigs": {"cc-plugin-agents-md@builtin": {"options": {"instructionFiles": "claude-md-and-agents-md"}}}`, plus `permissions.deny`, `permissions.ask`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`. Never owned: `model`, `effortLevel`, `modelSettings`, `tui`, any other key.
- Public repo: no company names, emails, account ids or internal hostnames in any file of this module.
- No code comments in hook scripts beyond the one-line purpose header the repo already uses on every script.
- No AI attribution in commits.

## Review Focus

1. **Rule syntax Claude Code rejects.** A deny or ask rule with a bad pattern or an unknown tool name is ignored with a startup warning; every owned rule must be in a form the permissions docs define, and Task 13 checks there are no warnings (Tasks 3, 13).
2. **Rules that over-ask.** `gh api` reads, own-branch pushes and `gh pr create` must not prompt; only writes and shared-branch actions do (Task 3).
3. **Live settings missing, empty or invalid JSON.** Install backs up an invalid file, writes owned keys into a fresh one, and never drops non-owned keys from a valid one (Task 2).
4. **jq absent on a fresh box.** Install and the context hooks need jq; doctor reports it with the fix (`brew install jq`) (Task 11).
5. **Leftover guard files.** The removed hook scripts must not stay linked in `~/.claude/hooks/` after an update (Task 3).

---

### Task 1: Module skeleton, working agreement, rules, resolver

**Files:**
- Create: `modules/claude/module.toml` (no `os` line: every OS), `modules/claude/README.md`, `modules/claude/RESOLVER.md`
- Create: `modules/claude/home/.claude/CLAUDE.md`, `home/.claude/rules/anand.md`, `home/.claude/rules/writing.md`, `home/.claude/rules/evidence.md`, `home/.claude/rules/building.md`
- Modify: `profiles/personal.toml`, `profiles/server.toml` (add `"claude"` last)
- Test: `tests/claude.bats`

**Interfaces:** Produces the linked tree `~/.claude/{CLAUDE.md,rules/*.md}` that later tasks extend under the same `home/.claude/`.

- [ ] **Step 1: Failing tests** in `tests/claude.bats`:
  - `claude module links CLAUDE.md and rules` — after `module_apply`, `~/.claude/CLAUDE.md` and each `~/.claude/rules/*.md` are symlinks into the repo.
  - `CLAUDE.md stays short` — `wc -l < CLAUDE.md` ≤ 45.
  - `working agreement carries the agreed rules` — CLAUDE.md contains each of: `literal question`, `UNVERIFIED`, `stands because`, `not a go`, `small reversible`, `No comments in code`, `AI slop`, `Do not overcorrect`, `outrank plugin skills`.
  - `no company data in the public module` — `grep -rniE 'work|backend|@[a-z0-9-]+\.(ai|com)' modules/claude` finds nothing.
  - `resolver names an owner for every rule heading` — each `##` heading in CLAUDE.md appears in RESOLVER.md.
  - `claude is in personal and server profiles`.
- [ ] **Step 2:** `bats tests/claude.bats` → FAIL (module missing).
- [ ] **Step 3:** Write CLAUDE.md from spec §1 (headings: Answering, Writing, Evidence, Deciding, Building, Working). Rules files hold the longer forms: `anand.md` (who he is, learning mode, doubts-not-tutoring, Hinglish, Mac + Coder), `writing.md` (slop list, "do not overcorrect", PR description pointer to the skill), `evidence.md` (observed / inferred / assumed labels, instrument before property, positive control for negatives, declared ≠ runtime, a check that could not run did not pass), `building.md` (ideal over existing pattern, minimal mechanisms full scope, no comments, never describe the diff in code, anti-cheat contract). RESOLVER.md: one table `rule → owner file`.
- [ ] **Step 4:** `bats tests/claude.bats` → PASS; `just lint` clean.
- [ ] **Step 5:** Commit `feat(claude): module with working agreement, rules and resolver`.

### Task 2: Owned settings merge

**Files:**
- Create: `modules/claude/settings.owned.json`, `lib/claude.sh`, `modules/claude/install.sh`, `modules/claude/doctor.sh`
- Test: `tests/claude.bats` (settings section)

**Interfaces:**
- Produces `claude_settings_merge <owned.json> <live.json>`: writes live = live with every top-level key of owned replaced by owned's value; creates live if absent; if live is invalid JSON, moves it to `live.invalid.<epoch>` first. Prints `skip settings` when unchanged, `merged settings` otherwise.
- Produces `claude_settings_drift <owned.json> <live.json>`: prints each owned key whose live value differs; exit 1 if any.

- [ ] **Step 1: Failing tests:**
  - `merge adds owned keys and keeps model and effort` — live `{"model":"opus","effortLevel":"xhigh"}` → after merge `.model=="opus"`, `.effortLevel=="xhigh"`, `.attribution==false`, `.cleanupPeriodDays==365`.
  - `merge is idempotent` — second run prints `skip settings`, file byte-identical.
  - `merge restores a loosened deny` — remove one entry from live `.permissions.deny`; merge puts it back.
  - `invalid live file is backed up and replaced` — live `{oops` → `live.invalid.*` exists, new live parses and has owned keys.
  - `missing live file is created`.
  - `doctor reports drift on owned keys only` — change `.model` → doctor silent; change `.cleanupPeriodDays` → doctor names `cleanupPeriodDays`.
  - `owned file sets the verbatim values` — `.permissions.defaultMode=="bypassPermissions"`, `.attribution==false`, `.cleanupPeriodDays==365`, `.pluginConfigs["cc-plugin-agents-md@builtin"].options.instructionFiles=="claude-md-and-agents-md"`; no `model`, `effortLevel`, `modelSettings` keys.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement with `jq -s '.[0] * (.[1] | with_entries(.))'`-style replacement per top-level key (replace, not deep-merge, so lists match owned exactly). Fill `settings.owned.json`: deny list (`Read(~/.secrets/**)`, `Edit(~/.secrets/**)`, `Read(**/.env)`, `Read(**/.env.*)`, `Read(~/.ssh/id_*)`, `Read(~/.aws/sso/cache/**)`, `Edit(~/.claude/settings.json)`, `Edit(~/.claude/hooks/**)`), allow list of read-only commands (`Bash(git status *)`, `Bash(git log *)`, `Bash(git diff *)`, `Bash(git show *)`, `Bash(rg *)`, `Bash(fd *)`, `Bash(ls *)`, `Bash(gh pr view *)`, `Bash(gh pr checks *)`, `Bash(kubectl get *)`, `Bash(kubectl describe *)`, `Bash(kubectl logs *)`), and the keys from Global Constraints. `hooks`, `statusLine`, `enabledPlugins` are filled by Tasks 3–9, 12, 11. install.sh calls the merge; doctor.sh calls drift.
- [ ] **Step 4:** Run → PASS; lint.
- [ ] **Step 5:** Commit `feat(claude): own harness settings, leave preferences alone`.

### Task 3: Native guard rails (replaces the custom guards of Tasks 3–7)

Built and later superseded: the secrets guard (commits bdbc4be..8131f66) and a stopped go-word gate (stash). Anand ruled out custom parsing: "i dont like these parsing and deterministic ways because u can't ever cover all ... keep it native and simple".

**Files:** Delete `hooks/secrets-guard.sh`, `hooks/secrets-scan.sh`; Modify `hooks/lib.sh` (keep only what Tasks 8–9 use), `settings.owned.json`, `home/.claude/rules/building.md` (test habits line), `tests/claude-hooks.bats`, `tests/claude.bats`; drop the stash.

**Interfaces:** `settings.owned.json` `permissions`: `defaultMode` `bypassPermissions`; no `allow`; `deny` and `ask` as below; `hooks` holds no PreToolUse entry.
- deny: `Read(~/.secrets/**)`, `Edit(~/.secrets/**)`, `Read(**/.env)`, `Read(**/.env.*)`, `Read(~/.ssh/id_*)`, `Read(~/.aws/sso/cache/**)`, `Edit(~/.claude/settings.json)`, `Bash(sops -d *)`, `Bash(sops decrypt *)`.
- ask: `Bash(gh pr merge *)`, `Bash(gh pr comment *)`, `Bash(gh pr review *)`, `Bash(gh workflow run *)`, `Bash(gh run rerun *)`, `Bash(gh run cancel *)`, `gh api` write forms (`-X`/`--method` POST, PATCH, PUT, DELETE; `-f`/`-F`/`--field`/`--raw-field`), `git push` to `main`, `master`, `develop`, `release*`, `git push --force*` and `-f`, `git push --delete *`, `git reset --hard*`, `git clean *`, `git branch -D *`, `docker system prune*`, `docker volume rm *`, and MCP tools that send, post, comment or merge: the Slack send and schedule tools, Linear `save_comment`, Notion `notion-create-comment`, and any GitHub connector merge or comment tool, written as exact `mcp__…` names or tool-name globs in the forms the permissions docs define.
- `--force-with-lease` on the own branch, own-branch push, `gh pr create` and every read do not match any ask rule.

- [ ] **Step 1: Failing tests:** `owned settings ask before outward and destructive actions` (each ask entry present verbatim), `owned settings deny secret files and sops decrypt`, `no allow rules are owned`, `no PreToolUse hook is owned`, `removed guard scripts are gone`, `building rules carry the test habits` (run only the changed tests, at most `-n 4`, one heavy run at a time).
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement; read the permissions docs (code.claude.com/docs/en/permissions) for each rule's exact form, especially mid-pattern wildcards and MCP tool-name globs; record the doc line each form relies on in the report.
- [ ] **Step 4:** Run `bats tests/claude*.bats`, `just lint` → PASS.
- [ ] **Step 5:** Commit `refactor(claude): native ask and deny rules replace the custom guards`; `git stash drop` the go-word stash.

### Task 8: Format on edit

**Files:** Create `hooks/format-on-edit.sh` (PostToolUse `Edit|Write`); Modify `settings.owned.json`; Test `tests/claude-hooks.bats`

- [ ] **Step 1: Failing tests:** `runs pre-commit on the edited file when the repo has .pre-commit-config.yaml` (fake `pre-commit` logs args), `runs shfmt on a .sh file`, `runs ruff format on a .py file`, `silent and exit 0 when no formatter exists`, `exit 0 even when the formatter fails`.
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): format the edited file with the repo's own formatter`.

### Task 9: Memory and context hooks

**Files:** Create `hooks/session-context.sh` (SessionStart, matchers `startup|resume|compact`), `hooks/subagent-context.sh` (SubagentStart), `home/.claude/rules/standing.md`; Modify `settings.owned.json`; Test `tests/claude-hooks.bats`

**Interfaces:**
- Ledger path: `~/.claude/projects/<slug>/memory/DECISIONS.md`, slug = cwd with `/` → `-` (the same rule Claude Code uses; verify on the real machine in Task 13). Row format `| date | decision | source | status |`; source is a quote or `INFERRED`.
- `session-context.sh` prints `rules/standing.md` and the ledger; when `source=resume` and the newest transcript line is ≥ 2 h old, adds "Start with a 5-line where we are / decided / next."
- `subagent-context.sh` prints the additionalContext JSON with the short standing rules (nothing fake, no skipped checks, stay on task, findings to the given file, return path + count).

- [ ] **Step 1: Failing tests:** `startup prints standing rules and the ledger`, `compact prints them`, `resume after 3 h asks for the summary`, `resume after 10 min does not`, `no ledger is fine`, `subagent context is valid JSON with eventName SubagentStart`.
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): re-inject rules and decisions; rules reach subagents`.

### Task 10: Skills and agents

**Files:**
- Create: `home/.claude/skills/{explain,grill,phase-close,pr-description,voice-draft,review-pr,research,find-past-session,handoff,retro,scout}/SKILL.md`, each with `evals/trigger.json`
- Create: `home/.claude/agents/{reviewer,researcher,worker}.md`
- Create: `home/.claude/skills/find-past-session/search.sh`, `home/.claude/skills/retro/pairs.sh`
- Test: `tests/claude-skills.bats`

**Interfaces:**
- Frontmatter: `name`, `description` (trigger text first), `disable-model-invocation: true` for `phase-close`, `handoff`, `voice-draft`.
- Agents: `reviewer` `tools: Read, Grep, Glob`, `model: opus`, `effort: high`; `researcher` `tools: Read, Grep, Glob, WebSearch, WebFetch`, `model: sonnet`, `effort: medium`; `worker` `model: haiku`, `effort: low`.
- `retro/pairs.sh <transcript.jsonl>` prints the conversation of one session as JSON lines `{role, ts, text}` (Anand's prompts and Claude's text only; no tool results, no hook output). With no argument it uses the newest transcript for the current cwd. The skill (`disable-model-invocation: true`) analyses that session, has the `researcher` agent cite docs for any plugin or feature suggestion, and outputs proposals grouped as rule add / update / delete, hook, skill or agent, plugin or feature. It edits nothing until Anand picks.
- `scout` (`disable-model-invocation: true`) reads the installed harness (`~/.claude/CLAUDE.md`, rules, skills, agents, hooks, enabled plugins), then has the `researcher` agent research by kind of source, not a fixed list: official (Claude Code changelog and docs, always), marketplaces (starting from the official one), trending code (starting from GitHub trending), discussion (starting from Hacker News and Reddit), practitioners (engineering blogs, newsletters); the agent discovers the specific places (default window 30 days, overridable as an argument). Output: one table, each row what / why it fits Anand / buzz / substance (what it does once its README or code is read, overlap, maintenance) / cost / adopt-try-skip / link; links checked; ends with where it looked and what it could not reach; nothing already installed; nothing applied without his go.
- `search.sh <phrase>...` greps `~/.claude/projects/*/*.jsonl` for any phrase, prints `session  date  matching line` (≤ 200 chars), never more than 30 lines.
- `evals/trigger.json`: `[{"query": …, "should_trigger": bool}]`, ≥ 6 entries, half `false`.

- [ ] **Step 1: Failing tests:** `every skill has name and description frontmatter on line 1`, `side-effect skills disable model invocation`, `no skill shares a name with a team skill` (pr-review, grill-me; the work layer extends the list from the team repo), `each skill ships a trigger eval with at least half negatives`, `agents carry the agreed tools, model and effort`, `reviewer cannot edit` (no Edit/Write/Bash in tools), `pr-description forbids a testing section and requires a diagram`, `search.sh finds a phrase in a fixture transcript and caps output`, `retro and scout are user-invoked only and never commit`, `pairs.sh prints only prompts and assistant text from a fixture transcript`, `pairs.sh defaults to the newest transcript for the cwd`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Write skills from spec §4 and the adopted team ideas: review-pr lenses find → refute → report ≥ strong, each finding tied to a line read, comment ledger, drafts via voice-draft; reviewer brief "oracle is the task and its claims, never the reasoning; flag tests that pass on a no-op"; phase-close includes doc-drift and the anti-cheat contract; explain uses map → one step → the diagram type that fits (flow, sequence, state, architecture) with balanced text → real terms each explained → resources → restate; offers an Artifact page for deep topics; grill numbers each question with a recommended answer.
- [ ] **Step 4–5:** PASS + lint → commit `feat(claude): skills and agents`.

### Task 11: Plugins, MCP, tools, doctor

**Files:** Modify `modules/claude/install.sh`, `doctor.sh`, `settings.owned.json` (`enabledPlugins`: superpowers, security-guidance, pyright-lsp, typescript-lsp true; learning-output-style false; code-review, code-simplifier false; `env.SECURITY_REVIEW_MODEL` = `claude-sonnet-5-5`); Create `modules/claude/Brewfile` (jq, pyright, typescript-language-server); Test `tests/claude.bats`

**Interfaces:** `install.sh` runs, idempotently: `claude plugin marketplace add anthropics/claude-plugins-official`, `claude plugin install <p>@claude-plugins-official --scope user` for each enabled plugin not listed by `claude plugin list`, `claude plugin uninstall` for code-review and code-simplifier when present, `claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp` when `claude mcp list` lacks it. No `claude` CLI → print the commands and continue. Doctor: owned-key drift (Task 2), every hook executable, enabled plugins installed, jq present.

- [ ] **Step 1: Failing tests** with a fake `claude` that logs calls: `installs missing plugins once`, `second run calls nothing`, `removes the duplicated review plugins`, `adds context7 once`, `no claude CLI prints the commands`, `doctor fails when a hook is not executable`, `doctor fails when jq is missing`.
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): plugins, context7, tools and doctor`.

### Task 12: Statusline

**Files:** Create `home/.claude/statusline.sh`; Modify `settings.owned.json` (`statusLine: {"type":"command","command":"$HOME/.claude/statusline.sh"}`); Test `tests/claude.bats`

- [ ] **Step 1: Failing tests** feeding statusline JSON: `shows model, context percent, repo and branch`, `marks a dirty tree with *`, `shows the background task count when present`, `outside a repo shows only model and context`, `one jq call` (count `jq` invocations via a wrapper).
- [ ] **Step 2–5:** FAIL → implement (`git -C "$cwd" --no-optional-locks`) → PASS + lint → commit `feat(claude): statusline`.

### Task 13: Verify on the real machine, install, close the phase

**Files:** Modify `docs/STATUS.md`, `docs/specs/07-claude-harness.md` (record verified facts); Delete `.superpowers/sdd/07-*` at the end

- [ ] **Step 1:** Verify the spec's five open facts in a throwaway session and record each result with its evidence: ask rules prompt and deny rules block in a bypass session, MCP globs included, and `claude` prints no rule warnings; settings names accepted (`claude doctor` shows no rejected entries); UserPromptSubmit `prompt` and SubagentStart firing (log lines from a temp hook); user hooks firing in a repo whose project settings allow `git push`; plugin bootstrap from a clean `CLAUDE_CONFIG_DIR`. Fix any rule that warns or does not fire.
- [ ] **Step 2:** Back up `~/.claude/settings.json`, run `dots install personal`, then `dots doctor` → clean.
- [ ] **Step 3:** Live checks: Read of `~/.secrets/secrets.yaml` refused; `gh pr merge` and `git push origin main` prompt; `/status` lists the hooks; statusline renders.
- [ ] **Step 4:** Full suite, lint, CI green on macOS and Ubuntu.
- [ ] **Step 5:** Fresh reviewer (the new `reviewer` agent), fix every finding, STATUS Phase 7 section, delete the ledger dir, commit `docs: phase 7 closed`.
