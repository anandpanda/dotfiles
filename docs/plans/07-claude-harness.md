# Claude Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `claude` module that installs Anand's Claude Code harness on every machine: the working agreement, six hooks, memory re-injection, nine skills, three agents, owned settings, plugins and a statusline.

**Architecture:** `modules/claude/home/.claude/**` is linked file by file like every other module. Hooks are bash scripts reading the hook JSON on stdin with `jq`, sharing `hooks/lib.sh`. `settings.json` is never linked: `install.sh` merges only the keys in `settings.owned.json` into the live file, so `/model` and `/config` changes stay Anand's.

**Tech Stack:** bash 3.2, jq, bats, shellcheck, shfmt; Claude Code ≥ 2.1.285.

**Spec:** `docs/specs/07-claude-harness.md`

## Global Constraints

- Bash 3.2 compatible (macOS); `shellcheck -S info` and `shfmt -i 2 -ci` clean; tests hermetic (temp HOME, fake binaries on PATH, never the real `~/.claude`).
- Hook protocol: read JSON on stdin; block with exit 2 and a reason on stderr; add context with plain stdout or `{"hookSpecificOutput":{"hookEventName":…,"additionalContext":…}}`; PreToolUse decisions with `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow|deny|ask","permissionDecisionReason":…}}`.
- Guards fail closed (unparseable input or missing `jq` → exit 2 with "hook input unreadable"); the formatter fails open.
- Every hook path in settings is absolute via `$HOME/.claude/hooks/<name>`.
- Sessions run in bypass permission mode by Anand's choice: `"permissions": {"defaultMode": "bypassPermissions"}` is owned. Prompts never appear, so every guard decides with `allow` or `deny` itself; `ask` is only the branch for a session Anand switches back to a prompting mode.
- Owned settings, verbatim: `"attribution": false`, `"cleanupPeriodDays": 365`, `"pluginConfigs": {"cc-plugin-agents-md@builtin": {"options": {"instructionFiles": "claude-md-and-agents-md"}}}`, plus `permissions.deny`, `permissions.allow`, `hooks`, `statusLine`, `enabledPlugins`, `extraKnownMarketplaces`. Never owned: `model`, `effortLevel`, `modelSettings`, `tui`, any other key.
- Public repo: no company names, emails, account ids or internal hostnames in any file of this module.
- No code comments in hook scripts beyond the one-line purpose header the repo already uses on every script.
- No AI attribution in commits.

## Review Focus

1. **Chained and wrapped commands.** `a && git push`, `bash -c "rm -rf x"`, `git -C repo push --force`, `/bin/rm -rf`, heredocs: guards match on the whole command string, not its first word (tests in Tasks 3, 4, 5).
2. **Paths spelled four ways.** `~/.secrets`, `$HOME/.secrets`, `/Users/x/.secrets`, `"$HOME"/.secrets/x`: the secrets guard normalises before matching (Task 3).
3. **Two sessions at once.** The go-word state is keyed by `session_id`, so approval in one session never unlocks another (Task 5).
4. **Live settings missing, empty or invalid JSON.** Install backs up an invalid file, writes owned keys into a fresh one, and never drops non-owned keys from a valid one (Task 2).
5. **jq absent on a fresh box.** Guards fail closed with a message naming the fix (`brew install jq`); doctor reports it (Tasks 3, 11).

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

### Task 3: Hook library and secrets guard

**Files:**
- Create: `modules/claude/home/.claude/hooks/lib.sh`, `hooks/secrets-guard.sh`, `hooks/secrets-scan.sh`
- Modify: `settings.owned.json` (`hooks.PreToolUse` matcher `Read|Grep|Bash` → secrets-guard; `hooks.PostToolUse` matcher `Bash` → secrets-scan)
- Test: `tests/claude-hooks.bats`

**Interfaces:**
- Produces in `lib.sh`: `hook_input` (reads stdin once into `$HOOK_JSON`; exit 2 "hook input unreadable" on bad JSON or missing jq), `hook_field <jq-path>`, `hook_block <reason>` (stderr + exit 2), `hook_context <event> <text>` (prints the additionalContext JSON), `hook_norm_path <path>` (expands `~`, `$HOME`, quotes → absolute).
- Secrets paths: `~/.secrets/`, `.env`, `.env.*`, `id_rsa`, `id_ed25519` (not `.pub`), `~/.aws/sso/cache/`, files matching `*backup*code*`, `*recovery*code*`, `*.pem`, `*.key`.

- [ ] **Step 1: Failing tests** (each feeds JSON on stdin to the script):
  - `blocks Read of each secret path spelled four ways` (`~`, `$HOME`, absolute, quoted).
  - `blocks Bash cat, grep, head, sed, less, source on a secret path`.
  - `blocks a literal token in a command` for `AKIA[0-9A-Z]{16}`, `ghp_…`, `github_pat_…`, `xox[abp]-…`, `glsa_…`, `sk-…`, `Bearer <20+ chars>`.
  - `blocks slicing or decoding a secret variable` — `printf "$TOKEN" | od -c`, `echo ${TOKEN:0:6}`.
  - `allows with-secrets and sops exec-env`.
  - `allows Read of an ordinary file and .env.example`.
  - `fails closed on unreadable input`.
  - `scan warns on token-shaped output, never blocks` — PostToolUse with `tool_response.stdout` containing `ghp_…` → stdout context mentions "looks like a token"; exit 0.
- [ ] **Step 2:** Run → FAIL.
- [ ] **Step 3:** Implement. Block reasons name the allowed route ("use `with-secrets <cmd>`").
- [ ] **Step 4:** Run → PASS; lint.
- [ ] **Step 5:** Commit `feat(claude): secrets guard hook`.

### Task 4: Destructive guard

**Files:** Create `hooks/destructive-guard.sh`; Modify `settings.owned.json` (PreToolUse `Bash`); Test `tests/claude-hooks.bats`

**Interfaces:** Consumes `lib.sh`. Decision: `deny` with the target list in the reason when gated and not approved by Task 5's `approval_given` (sourced from `hooks/approval.sh`, Task 5); always `deny` for deleting a dir with unpushed git work and for Bash writes into `~/.claude/`.

- [ ] **Step 1: Failing tests:**
  - `gates rm -rf outside cwd and scratchpad`, `allows rm -rf inside cwd`, `allows rm -rf under $TMPDIR`.
  - `gates git clean, reset --hard, branch -D, push --force`, `allows push --force-with-lease`.
  - `gates docker system prune, docker volume rm, sudo rm, brew uninstall`.
  - `catches wrapped forms` — `a && rm -rf ~/x`, `bash -c "rm -rf ~/x"`, `/bin/rm -rf ~/x`, `git -C repo reset --hard`.
  - `refuses deleting a repo with unpushed branches even when approved` — temp repo with a local-only branch.
  - `refuses Bash writes into ~/.claude` — `sed -i … ~/.claude/settings.json`, `> ~/.claude/hooks/x`.
  - `passes a gated command when approval_given is true` (stub).
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): destructive guard hook`.

### Task 5: Go-word capture and outward gate

**Files:** Create `hooks/prompt-capture.sh` (UserPromptSubmit), `hooks/approval.sh` (library), `hooks/outward-gate.sh` (PreToolUse `Bash`); Modify `settings.owned.json`; Test `tests/claude-hooks.bats`

**Interfaces:**
- `prompt-capture.sh` writes `~/.claude/state/prompt-<session_id>.json` = `{"prompt": <text>, "ts": <epoch>}` from the hook's `prompt` field; prints nothing.
- `approval.sh` produces `approval_given <session_id> <action-word>`: true when the stored prompt (≤ 10 min old) contains a go-word for that action (`merge`, `push`, `post`, `send`, `run`, `do it`, `go`, `ship`), or is a short yes (`yes|y|haan|ha|ok|okay|done|sure`, ≤ 3 words) and the latest assistant turn in `transcript_path` mentions the same action word and ends with `?`. Questions (`?` in the prompt) never count.
- Gated set: `gh pr merge`, `gh pr comment`, `gh pr review`, `gh api` with `-X POST|PATCH|PUT|DELETE` or `-f`/`--field`, `gh workflow run`, `gh run rerun|cancel`, Slack send commands, `git push` to `main|master|release|develop` or a branch whose upstream author is not the user. Ungated: `git push` of the current own branch, `gh pr create`.
- Mode: `permission_mode` `default|acceptEdits|plan` → `ask`; `bypassPermissions|auto|dontAsk` → `allow` if `approval_given`, else `deny` "ask Anand first: say 'push it' / 'merge it'".

- [ ] **Step 1: Failing tests:**
  - `capture stores the prompt per session`.
  - `merge is denied without a go-word in bypass mode`, `allowed after "merge it"`, `asks in default mode`.
  - `a question never approves` — prompt `"should we merge?"` → deny.
  - `short yes approves only the action Claude asked about` — transcript ends `"Merge #12?"` + prompt `yes` → merge allowed, `gh pr comment` denied.
  - `approval in one session does not unlock another`.
  - `stale approval expires after 10 minutes`.
  - `own branch push and gh pr create pass`.
  - `push to main is gated`, `catches a && gh pr merge`.
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): outward-action gate with go-word`.

### Task 6: Compute guard

**Files:** Create `hooks/compute-guard.sh` (PreToolUse `Bash`); Modify `settings.owned.json`; Test `tests/claude-hooks.bats`

- [ ] **Step 1: Failing tests:** `denies pytest on a directory`, `denies pytest with -n above 4`, `denies a second pytest while one runs` (fake `pgrep` on PATH returns 1), `allows pytest on named test files`, `allows bats on a single file`; the deny message contains "run the changed tests".
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): compute guard hook`.

### Task 7: Publish check

**Files:** Create `hooks/publish-check.sh` (PreToolUse `Bash`), `hooks/publish-readback.sh` (PostToolUse `Bash`), `hooks/publish-words.txt`; Modify `settings.owned.json`; Test `tests/claude-hooks.bats`

**Interfaces:** Extracts body text from `gh pr create|edit --body <s>`, `--body-file <f>`, heredoc bodies, `gh pr comment --body`, `gh api … -f body=`. Word list sections: `slop:` (ensuring, leveraging, utilizing, robust, comprehensive, seamless, it is worth noting, importantly, note that, a series of), `tells:` (great catch, good catch, great question, great point, generated with, generated by, Co-Authored-By), `hedge:` (likely, probably, I believe, should work, might). PR bodies additionally need a ```` ```mermaid ```` or ```` ```diff ```` block and no heading matching `test|testing|verification`.

- [ ] **Step 1: Failing tests:** `denies a PR body without a diagram`, `denies a testing section`, `denies each slop, tell and hedge word with the word named in the reason`, `allows a clean body with a mermaid block`, `reads --body-file and heredoc bodies`, `comments need no diagram`, `readback warns when the posted text differs from the checked text` (fake `gh` prints a different body).
- [ ] **Step 2–5:** FAIL → implement → PASS + lint → commit `feat(claude): publish check on PR and comment text`.

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
- Create: `home/.claude/skills/{explain,grill-me,phase-close,pr-description,voice-draft,review-pr,research,find-past-session,handoff}/SKILL.md`, each with `evals/trigger.json`
- Create: `home/.claude/agents/{reviewer,researcher,worker}.md`
- Create: `home/.claude/skills/find-past-session/search.sh`
- Test: `tests/claude-skills.bats`

**Interfaces:**
- Frontmatter: `name`, `description` (trigger text first), `disable-model-invocation: true` for `phase-close`, `handoff`, `voice-draft`.
- Agents: `reviewer` `tools: Read, Grep, Glob`, `model: opus`, `effort: high`; `researcher` `tools: Read, Grep, Glob, WebSearch, WebFetch`, `model: sonnet`, `effort: medium`; `worker` `model: haiku`, `effort: low`.
- `search.sh <phrase>...` greps `~/.claude/projects/*/*.jsonl` for any phrase, prints `session  date  matching line` (≤ 200 chars), never more than 30 lines.
- `evals/trigger.json`: `[{"query": …, "should_trigger": bool}]`, ≥ 6 entries, half `false`.

- [ ] **Step 1: Failing tests:** `every skill has name and description frontmatter on line 1`, `side-effect skills disable model invocation`, `review-pr does not shadow a team skill named pr-review`, `each skill ships a trigger eval with at least half negatives`, `agents carry the agreed tools, model and effort`, `reviewer cannot edit` (no Edit/Write/Bash in tools), `pr-description forbids a testing section and requires a diagram`, `search.sh finds a phrase in a fixture transcript and caps output`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Write skills from spec §4 and the adopted team ideas: review-pr lenses find → refute → report ≥ strong, each finding tied to a line read, comment ledger, drafts via voice-draft; reviewer brief "oracle is the task and its claims, never the reasoning; flag tests that pass on a no-op"; phase-close includes doc-drift and the anti-cheat contract; explain uses map → one step → smallest diagram → restate; grill-me numbers each question with a recommended answer.
- [ ] **Step 4–5:** PASS + lint → commit `feat(claude): skills and agents`.

### Task 11: Plugins, MCP, tools, doctor

**Files:** Modify `modules/claude/install.sh`, `doctor.sh`, `settings.owned.json` (`enabledPlugins`: superpowers, security-guidance, pyright-lsp, typescript-lsp true; learning-output-style false; code-review, code-simplifier false; `env.SECURITY_REVIEW_MODEL` = `claude-sonnet-5-5`); Create `modules/claude/Brewfile` (jq, pyright, typescript-language-server); Test `tests/claude.bats`

**Interfaces:** `install.sh` runs, idempotently: `claude plugin marketplace add anthropics/claude-plugins-official`, `claude plugin install <p>@claude-plugins-official --scope user` for each enabled plugin not listed by `claude plugin list`, `claude plugin uninstall` for code-review and code-simplifier when present, `claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp` when `claude mcp list` lacks it. No `claude` CLI → print the commands and continue. Doctor: owned-key drift (Task 2), every hook executable and its `--self-test` passing, enabled plugins installed, jq present.

- [ ] **Step 1: Failing tests** with a fake `claude` that logs calls: `installs missing plugins once`, `second run calls nothing`, `removes the duplicated review plugins`, `adds context7 once`, `no claude CLI prints the commands`, `doctor fails when a hook is not executable`, `doctor fails when jq is missing`.
- [ ] **Step 2–5:** FAIL → implement (each hook gets a `--self-test` branch that runs one allow and one block case) → PASS + lint → commit `feat(claude): plugins, context7, tools and doctor`.

### Task 12: Statusline

**Files:** Create `home/.claude/statusline.sh`; Modify `settings.owned.json` (`statusLine: {"type":"command","command":"$HOME/.claude/statusline.sh"}`); Test `tests/claude.bats`

- [ ] **Step 1: Failing tests** feeding statusline JSON: `shows model, context percent, repo and branch`, `marks a dirty tree with *`, `shows the background task count when present`, `outside a repo shows only model and context`, `one jq call` (count `jq` invocations via a wrapper).
- [ ] **Step 2–5:** FAIL → implement (`git -C "$cwd" --no-optional-locks`) → PASS + lint → commit `feat(claude): statusline`.

### Task 13: Verify on the real machine, install, close the phase

**Files:** Modify `docs/STATUS.md`, `docs/specs/07-claude-harness.md` (record verified facts); Delete `.superpowers/sdd/07-*` at the end

- [ ] **Step 1:** Verify the spec's five open facts in a throwaway session and record each result with its evidence: hook `ask` under bypass mode; settings names accepted (`claude doctor` shows no rejected entries); UserPromptSubmit `prompt` and SubagentStart firing (log lines from a temp hook); user hooks firing in a repo whose project settings allow `git push`; plugin bootstrap from a clean `CLAUDE_CONFIG_DIR`. Adjust the outward gate if `ask` behaves differently.
- [ ] **Step 2:** Back up `~/.claude/settings.json`, run `dots install personal`, then `dots doctor` → clean.
- [ ] **Step 3:** Live checks: `cat ~/.secrets/secrets.yaml` refused; a PR body without a diagram refused; `git push origin main` refused until "push it"; `/status` lists the hooks; statusline renders.
- [ ] **Step 4:** Full suite, lint, CI green on macOS and Ubuntu.
- [ ] **Step 5:** Fresh reviewer (the new `reviewer` agent), fix every finding, STATUS Phase 7 section, delete the ledger dir, commit `docs: phase 7 closed`.
